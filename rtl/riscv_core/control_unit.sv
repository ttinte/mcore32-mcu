//-----------------------------------------------------------------------------
//  Module   : control_unit
//  Children : None
//
//  Description:
//     Multicycle control FSM for the RV32 core.
//     Instruction fetch requires at least one-cycle response latency.
//     Memory errors are sampled only when memory ready is asserted.
//     trap_o.valid is a one-cycle pulse during trap entry.
//     Faulting instructions do not write GPRs or retire.
//     Supports CSR instructions and MRET; interrupts are not supported.
//
//-----------------------------------------------------------------------------
import rv32_pkg::*;

module control_unit (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic [31:0]  instr_i,
    input  alu_flags_t   flags_i,
    output decode_ctrl_t ctrl_o,

    output logic         mem_valid_o,
    input  logic         mem_ready_i,
    input  logic         mem_error_i,

    input  logic [31:0]  fetch_pc_i,
    input  logic [31:0]  instr_pc_i,
    input  logic [31:0]  alu_result_i,

    input  logic         csr_valid_i,
    output exception_t   trap_o,
    output logic         trace_valid_o
);

    localparam logic [2:0] FUNCT3_ADD_SUB   = 3'b000;     //OP
    localparam logic [2:0] FUNCT3_SLL       = 3'b001;
    localparam logic [2:0] FUNCT3_SLT       = 3'b010;
    localparam logic [2:0] FUNCT3_SLTU      = 3'b011;
    localparam logic [2:0] FUNCT3_XOR       = 3'b100;
    localparam logic [2:0] FUNCT3_SRL_SRA   = 3'b101;
    localparam logic [2:0] FUNCT3_OR        = 3'b110;
    localparam logic [2:0] FUNCT3_AND       = 3'b111;

    localparam logic [2:0] FUNCT3_ADDI      = 3'b000;     //OP-IMM
    localparam logic [2:0] FUNCT3_SLLI      = 3'b001;
    localparam logic [2:0] FUNCT3_SLTI      = 3'b010;
    localparam logic [2:0] FUNCT3_SLTIU     = 3'b011;
    localparam logic [2:0] FUNCT3_XORI      = 3'b100;
    localparam logic [2:0] FUNCT3_SRLI_SRAI = 3'b101;
    localparam logic [2:0] FUNCT3_ORI       = 3'b110;
    localparam logic [2:0] FUNCT3_ANDI      = 3'b111;

    localparam logic [2:0] FUNCT3_LB        = 3'b000;     //LOAD
    localparam logic [2:0] FUNCT3_LH        = 3'b001;
    localparam logic [2:0] FUNCT3_LW        = 3'b010;
    localparam logic [2:0] FUNCT3_LBU       = 3'b100;
    localparam logic [2:0] FUNCT3_LHU       = 3'b101;
    localparam logic [2:0] FUNCT3_SB        = 3'b000;     //STORE
    localparam logic [2:0] FUNCT3_SH        = 3'b001;
    localparam logic [2:0] FUNCT3_SW        = 3'b010;

    localparam logic [2:0] FUNCT3_JALR      = 3'b000;     //JALR
    localparam logic [2:0] FUNCT3_BEQ       = 3'b000;     //BRANCH
    localparam logic [2:0] FUNCT3_BNE       = 3'b001;
    localparam logic [2:0] FUNCT3_BLT       = 3'b100;
    localparam logic [2:0] FUNCT3_BGE       = 3'b101;
    localparam logic [2:0] FUNCT3_BLTU      = 3'b110;
    localparam logic [2:0] FUNCT3_BGEU      = 3'b111;

    localparam logic [2:0] FUNCT3_CSRRW     = 3'b001;     //CSR
    localparam logic [2:0] FUNCT3_CSRRS     = 3'b010;
    localparam logic [2:0] FUNCT3_CSRRC     = 3'b011;
    localparam logic [2:0] FUNCT3_CSRRWI    = 3'b101;
    localparam logic [2:0] FUNCT3_CSRRSI    = 3'b110;
    localparam logic [2:0] FUNCT3_CSRRCI    = 3'b111;

    typedef enum logic [3:0] {
        ST_IF_REQ,
        ST_IF_RESP,
        ST_ID,
        ST_JALR_TARGET,
        ST_EX,
        ST_LD,
        ST_ST,
        ST_WB,
        ST_TRAP,
        ST_CSR,
        ST_MRET,
        ST_ILLEGAL
    } state_e;

    state_e state_q, state_d;
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    logic        take_branch;
    logic [31:0] branch_target;

    logic fetch_fault;
    logic illegal_instr;
    logic addr_misaligned;
    logic data_misaligned;
    logic load_fault;
    logic store_fault;
    exception_t exc_d;

    logic is_op;
    logic is_op_imm;
    logic is_load;
    logic is_store;
    logic is_branch;
    logic is_auipc;
    logic is_lui;
    logic is_jalr;
    logic is_jal;
    logic is_csr;
    logic is_mret;

    assign opcode = instr_i[6:0];
    assign funct3 = instr_i[14:12];
    assign funct7 = instr_i[31:25];

    assign is_op     = (opcode == OPCODE_OP);
    assign is_op_imm = (opcode == OPCODE_OP_IMM);
    assign is_load   = (opcode == OPCODE_LOAD);
    assign is_store  = (opcode == OPCODE_STORE);
    assign is_branch = (opcode == OPCODE_BRANCH);
    assign is_auipc  = (opcode == OPCODE_AUIPC);
    assign is_lui    = (opcode == OPCODE_LUI);
    assign is_jalr   = (opcode == OPCODE_JALR);
    assign is_jal    = (opcode == OPCODE_JAL);
    assign is_csr    = (opcode == OPCODE_CSR) && (funct3[1:0] != 2'b00);
    assign is_mret   = (instr_i == 32'h3020_0073);

    // Main control fsm
    always_comb begin
        state_d             = state_q;
        mem_valid_o         = 1'b0;
        ctrl_o.mret         = 1'b0;
        ctrl_o.pc_we        = 1'b0;
        ctrl_o.pc_clear_lsb = 1'b0;
        ctrl_o.mem_addr_sel = MEM_ADDR_PC;
        ctrl_o.mem_we       = 1'b0;
        ctrl_o.load_op      = LOAD_NONE;
        ctrl_o.store_op     = STORE_NONE;
        ctrl_o.ir_we        = 1'b0;
        ctrl_o.reg_we       = 1'b0;
        ctrl_o.imm_sel      = IMM_NONE;
        ctrl_o.op_a_sel     = OP_A_PC;
        ctrl_o.op_b_sel     = OP_B_FOUR;
        ctrl_o.alu_op       = ALU_ADD;
        ctrl_o.alu_out_we   = 1'b0;
        ctrl_o.csr_we       = 1'b0;
        ctrl_o.csr_op       = CSR_RW;
        ctrl_o.result_sel   = RESULT_ALU_OUT_Q;

        unique case (state_q)
            ST_IF_REQ: begin
                state_d = ST_IF_RESP;

                mem_valid_o       = 1'b1;
                ctrl_o.alu_out_we = 1'b1;
            end

            ST_IF_RESP: begin
                state_d = ST_IF_RESP;

                mem_valid_o = 1'b1;
                if (mem_ready_i) begin
                    state_d = ST_ID;
                    ctrl_o.pc_we = 1'b1;
                    ctrl_o.ir_we = 1'b1;
                end
            end

            ST_ID: begin
                state_d = ST_EX;

                if (is_branch) begin
                    ctrl_o.imm_sel    = IMM_B;
                    ctrl_o.op_a_sel   = OP_A_OLD_PC;
                    ctrl_o.op_b_sel   = OP_B_IMM;
                    ctrl_o.alu_out_we = 1'b1;
                end

                if (is_auipc) begin
                    state_d = ST_WB;

                    ctrl_o.imm_sel    = IMM_U;
                    ctrl_o.op_a_sel   = OP_A_OLD_PC;
                    ctrl_o.op_b_sel   = OP_B_IMM;
                    ctrl_o.alu_out_we = 1'b1;
                end

                if (is_lui) begin
                    state_d = ST_WB;

                    ctrl_o.imm_sel    = IMM_U;
                    ctrl_o.op_b_sel   = OP_B_IMM;
                    ctrl_o.alu_op     = ALU_PASS_B;
                    ctrl_o.alu_out_we = 1'b1;
                end

                if (is_jalr) begin
                    state_d = ST_JALR_TARGET;
                end

                if (is_jal) begin
                    ctrl_o.imm_sel    = IMM_J;
                    ctrl_o.op_a_sel   = OP_A_OLD_PC;
                    ctrl_o.op_b_sel   = OP_B_IMM;
                    ctrl_o.alu_out_we = 1'b1;
                end

                if (is_csr) begin
                    state_d = ST_CSR;
                end else if (is_mret) begin
                    state_d = ST_MRET;
                end
            end

            ST_JALR_TARGET: begin
                state_d = ST_EX;

                ctrl_o.imm_sel    = IMM_I;
                ctrl_o.op_a_sel   = OP_A_RS1;
                ctrl_o.op_b_sel   = OP_B_IMM;
                ctrl_o.alu_out_we = 1'b1;
            end

            ST_EX: begin
                if (is_op) begin
                    state_d = ST_WB;

                    ctrl_o.op_a_sel   = OP_A_RS1;
                    ctrl_o.op_b_sel   = OP_B_RS2;
                    ctrl_o.alu_out_we = 1'b1;

                    unique case({funct7, funct3})
                        {7'h00, FUNCT3_ADD_SUB}: ctrl_o.alu_op = ALU_ADD;
                        {7'h20, FUNCT3_ADD_SUB}: ctrl_o.alu_op = ALU_SUB;
                        {7'h00, FUNCT3_SLL}:     ctrl_o.alu_op = ALU_SLL;
                        {7'h00, FUNCT3_SLT}:     ctrl_o.alu_op = ALU_SLT;
                        {7'h00, FUNCT3_SLTU}:    ctrl_o.alu_op = ALU_SLTU;
                        {7'h00, FUNCT3_XOR}:     ctrl_o.alu_op = ALU_XOR;
                        {7'h00, FUNCT3_SRL_SRA}: ctrl_o.alu_op = ALU_SRL;
                        {7'h20, FUNCT3_SRL_SRA}: ctrl_o.alu_op = ALU_SRA;
                        {7'h00, FUNCT3_OR}:      ctrl_o.alu_op = ALU_OR;
                        {7'h00, FUNCT3_AND}:     ctrl_o.alu_op = ALU_AND;
                        default: ;
                    endcase
                end

                else if (is_op_imm) begin
                    state_d = ST_WB;

                    ctrl_o.imm_sel    = IMM_I;
                    ctrl_o.op_a_sel   = OP_A_RS1;
                    ctrl_o.op_b_sel   = OP_B_IMM;
                    ctrl_o.alu_out_we = 1'b1;

                    unique case(funct3)
                        FUNCT3_ADDI:  ctrl_o.alu_op = ALU_ADD;
                        FUNCT3_SLTI:  ctrl_o.alu_op = ALU_SLT;
                        FUNCT3_SLTIU: ctrl_o.alu_op = ALU_SLTU;
                        FUNCT3_XORI:  ctrl_o.alu_op = ALU_XOR;
                        FUNCT3_ORI:   ctrl_o.alu_op = ALU_OR;
                        FUNCT3_ANDI:  ctrl_o.alu_op = ALU_AND;
                        FUNCT3_SLLI:  begin
                            if (funct7 == 7'h00) ctrl_o.alu_op = ALU_SLL;
                        end
                        FUNCT3_SRLI_SRAI: begin
                            if (funct7 == 7'h00)
                                ctrl_o.alu_op = ALU_SRL;
                            else if (funct7 == 7'h20)
                                ctrl_o.alu_op = ALU_SRA;
                        end
                        default: ;
                    endcase
                end

                else if (is_load) begin
                    state_d = ST_LD;

                    ctrl_o.imm_sel  = IMM_I;
                    ctrl_o.op_a_sel = OP_A_RS1;
                    ctrl_o.op_b_sel = OP_B_IMM;
                    ctrl_o.alu_out_we = 1'b1;
                end

                else if (is_store) begin
                    state_d = ST_ST;

                    ctrl_o.imm_sel  = IMM_S;
                    ctrl_o.op_a_sel = OP_A_RS1;
                    ctrl_o.op_b_sel = OP_B_IMM;
                    ctrl_o.alu_out_we = 1'b1;
                end

                else if (is_branch) begin
                    state_d = ST_IF_REQ;

                    ctrl_o.pc_we      = take_branch;
                    ctrl_o.op_a_sel   = OP_A_RS1;
                    ctrl_o.op_b_sel   = OP_B_RS2;
                    ctrl_o.alu_op     = ALU_SUB;
                end

                else if (is_jalr) begin
                    state_d = ST_WB;

                    ctrl_o.pc_we        = 1'b1;
                    ctrl_o.pc_clear_lsb = 1'b1;
                    ctrl_o.op_a_sel     = OP_A_OLD_PC;
                    ctrl_o.op_b_sel     = OP_B_FOUR;
                    ctrl_o.alu_out_we = 1'b1;
                end

                else if (is_jal) begin
                    state_d = ST_WB;

                    ctrl_o.pc_we        = 1'b1;
                    ctrl_o.op_a_sel     = OP_A_OLD_PC;
                    ctrl_o.op_b_sel     = OP_B_FOUR;
                    ctrl_o.alu_out_we = 1'b1;
                end
            end

            ST_LD: begin
                state_d = mem_ready_i ? ST_WB : ST_LD;

                mem_valid_o = 1'b1;
                ctrl_o.mem_addr_sel = MEM_ADDR_RESULT;

                unique case (funct3)
                    FUNCT3_LB:  ctrl_o.load_op = LOAD_BYTE;
                    FUNCT3_LH:  ctrl_o.load_op = LOAD_HALF;
                    FUNCT3_LW:  ctrl_o.load_op = LOAD_WORD;
                    FUNCT3_LBU: ctrl_o.load_op = LOAD_BYTEU;
                    FUNCT3_LHU: ctrl_o.load_op = LOAD_HALFU;
                    default: ;
                endcase
            end

            ST_ST: begin
                state_d = mem_ready_i ? ST_IF_REQ : ST_ST;

                mem_valid_o = 1'b1;
                ctrl_o.mem_addr_sel = MEM_ADDR_RESULT;
                ctrl_o.mem_we = 1'b1;

                unique case(funct3)
                    FUNCT3_SB: ctrl_o.store_op = STORE_BYTE;
                    FUNCT3_SH: ctrl_o.store_op = STORE_HALF;
                    FUNCT3_SW: ctrl_o.store_op = STORE_WORD;
                    default: ;
                endcase
            end

            ST_WB: begin
                state_d = ST_IF_REQ;

                ctrl_o.reg_we = 1'b1;
                if (is_load) begin
                    ctrl_o.result_sel = RESULT_LOAD_DATA_Q;
                end else if (is_csr) begin
                    ctrl_o.result_sel = RESULT_CSR_Q;
                end
            end

            ST_TRAP: begin
                state_d = ST_IF_REQ;
            end

            ST_CSR: begin
                state_d = ST_WB;

                ctrl_o.csr_we = (funct3[1:0] == CSR_RW) || (instr_i[19:15] != 5'd0);
                unique case (funct3)
                    FUNCT3_CSRRW,
                    FUNCT3_CSRRWI: ctrl_o.csr_op = CSR_RW;
                    FUNCT3_CSRRS,
                    FUNCT3_CSRRSI: ctrl_o.csr_op = CSR_RS;
                    FUNCT3_CSRRC,
                    FUNCT3_CSRRCI: ctrl_o.csr_op = CSR_RC;
                    default: ;
                endcase
            end

            ST_MRET: begin
                state_d = ST_IF_REQ;
                ctrl_o.mret = 1'b1;
            end

            ST_ILLEGAL: begin
                state_d = ST_ILLEGAL;
            end

            default: begin
                state_d = ST_ILLEGAL;
            end
        endcase

        if (exc_d.valid) begin
            state_d = ST_TRAP;
            ctrl_o.pc_we  = 1'b0;
            ctrl_o.ir_we  = 1'b0;
            ctrl_o.reg_we = 1'b0;
            mem_valid_o   = 1'b0;
            ctrl_o.mem_we = 1'b0;
        end
    end

    // Branch condition decode
    always_comb begin
        take_branch = 1'b0;

        if (is_branch) begin
            unique case (funct3)
                FUNCT3_BEQ:  take_branch = flags_i.zero;
                FUNCT3_BNE:  take_branch = ~flags_i.zero;
                FUNCT3_BLT:  take_branch = (flags_i.sign ^ flags_i.overflow);
                FUNCT3_BGE:  take_branch = ~(flags_i.sign ^ flags_i.overflow);
                FUNCT3_BLTU: take_branch = ~flags_i.carry;
                FUNCT3_BGEU: take_branch = flags_i.carry;
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            state_q <= ST_IF_REQ;
            trap_o  <= '0;
        end else begin
            state_q <= state_d;
            trap_o  <= exc_d;
        end
    end

    // Instruction legality check
    always_comb begin
        fetch_fault     = (state_q == ST_IF_RESP) && mem_ready_i && mem_error_i;
        illegal_instr   = (state_q == ST_ID);
        addr_misaligned = 1'b0;
        data_misaligned = 1'b0;
        load_fault      = (state_q == ST_LD) && mem_ready_i && mem_error_i;
        store_fault     = (state_q == ST_ST) && mem_ready_i && mem_error_i;

        if (state_q == ST_ID) begin
            if (is_op) begin
                unique case({funct7, funct3})
                    {7'h00, FUNCT3_ADD_SUB},
                    {7'h20, FUNCT3_ADD_SUB},
                    {7'h00, FUNCT3_SLL},
                    {7'h00, FUNCT3_SLT},
                    {7'h00, FUNCT3_SLTU},
                    {7'h00, FUNCT3_XOR},
                    {7'h00, FUNCT3_SRL_SRA},
                    {7'h20, FUNCT3_SRL_SRA},
                    {7'h00, FUNCT3_OR},
                    {7'h00, FUNCT3_AND}: illegal_instr = 1'b0;
                    default: ;
                endcase
            end

            if (is_op_imm) begin
                unique case(funct3)
                    FUNCT3_ADDI,
                    FUNCT3_SLTI,
                    FUNCT3_SLTIU,
                    FUNCT3_XORI,
                    FUNCT3_ORI,
                    FUNCT3_ANDI:      illegal_instr = 1'b0;
                    FUNCT3_SLLI:      illegal_instr = (funct7 != 7'h00);
                    FUNCT3_SRLI_SRAI: illegal_instr = (funct7 != 7'h00) && (funct7 != 7'h20);
                    default: ;
                endcase
            end

            if (is_load) begin
                unique case (funct3)
                    FUNCT3_LB,
                    FUNCT3_LH,
                    FUNCT3_LW,
                    FUNCT3_LBU,
                    FUNCT3_LHU: illegal_instr = 1'b0;
                    default: ;
                endcase
            end

            if (is_store) begin
                unique case(funct3)
                    FUNCT3_SB,
                    FUNCT3_SH,
                    FUNCT3_SW: illegal_instr = 1'b0;
                    default: ;
                endcase
            end

            if (is_branch) begin
                unique case (funct3)
                    FUNCT3_BEQ,
                    FUNCT3_BNE,
                    FUNCT3_BLT,
                    FUNCT3_BGE,
                    FUNCT3_BLTU,
                    FUNCT3_BGEU: illegal_instr = 1'b0;
                    default: ;
                endcase
            end

            if (is_auipc || is_lui || is_jal) begin
                illegal_instr = 1'b0;
            end

            if (is_jalr && (funct3 == FUNCT3_JALR)) begin
                illegal_instr = 1'b0;
            end

            if (is_csr) begin
                unique case (funct3)
                    FUNCT3_CSRRW,
                    FUNCT3_CSRRWI,
                    FUNCT3_CSRRS,
                    FUNCT3_CSRRSI,
                    FUNCT3_CSRRC,
                    FUNCT3_CSRRCI: illegal_instr = !csr_valid_i;
                    default: ;
                endcase
            end

            if (is_mret) begin
                illegal_instr = 1'b0;
            end
        end
        
        if ((state_q == ST_EX) && ((is_branch && take_branch) || is_jalr || is_jal)) begin
            addr_misaligned = is_jalr ? alu_result_i[1] : |alu_result_i[1:0];
        end

        if ((state_q == ST_LD) || (state_q == ST_ST)) begin
            unique case (funct3)
                3'b001,
                3'b101: data_misaligned = alu_result_i[0];
                3'b010: data_misaligned = |alu_result_i[1:0];
                default: ;
            endcase
        end
    end

    assign branch_target = is_jalr ? {alu_result_i[31:1], 1'b0} : alu_result_i;

    exception u_exception (
        .fetch_fault_i      (fetch_fault),
        .illegal_instr_i    (illegal_instr),
        .addr_misaligned_i  (addr_misaligned),
        .data_misaligned_i  (data_misaligned),
        .load_fault_i       (load_fault),
        .store_fault_i      (store_fault),
        .is_load_i          (is_load),
        .fetch_pc_i         (fetch_pc_i),
        .instr_pc_i         (instr_pc_i),
        .instr_i            (instr_i),
        .branch_target_i    (branch_target),
        .data_addr_i        (alu_result_i),
        .exc_o              (exc_d)
    );

    assign trace_valid_o = ((state_q == ST_ST) && mem_valid_o && mem_ready_i && !mem_error_i) ||
                           ((state_q == ST_EX) && is_branch && !(take_branch && addr_misaligned)) ||
                           (state_q == ST_WB || (state_q == ST_MRET));

endmodule
