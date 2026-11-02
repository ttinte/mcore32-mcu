//-----------------------------------------------------------------------------
//  Module   : control_unit
//  Children : None
//
//  Description:
//     Multicycle control FSM for the RV32 core.
//     Instruction fetch requires at least one-cycle response latency;
//     zero-wait fetch completion is not supported.
//     Load/store requests wait for ready.
//     Illegal instructions, bus errors and misaligned accesses halt the core.
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

    input  logic [1:0]   alu_result_i,

    output logic         trace_valid_o,
    output logic         illegal_instr_o
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

    typedef enum logic [3:0] {
        ST_IF_REQ,
        ST_IF_RESP,
        ST_ID,
        ST_JALR_TARGET,
        ST_EX,
        ST_LD,
        ST_ST,
        ST_WB,
        ST_ILLEGAL
    } state_e;

    state_e state_q, state_d;
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    logic take_branch;
    logic illegal_instr;
    logic addr_misaligned;
    logic data_misaligned;

    logic is_op;
    logic is_op_imm;
    logic is_load;
    logic is_store;
    logic is_branch;
    logic is_auipc;
    logic is_lui;
    logic is_jalr;
    logic is_jal;

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

    // Main control fsm
    always_comb begin
        state_d             = state_q;
        illegal_instr_o     = 1'b0;
        mem_valid_o         = 1'b0;
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
        ctrl_o.result_sel   = RESULT_ALU_OUT_Q;

        unique case (state_q)
            ST_IF_REQ: begin
                state_d = ST_IF_RESP;

                mem_valid_o       = 1'b1;
                ctrl_o.alu_out_we = 1'b1;
            end

            ST_IF_RESP: begin
                mem_valid_o = 1'b1;

                if (mem_ready_i) begin
                    state_d = mem_error_i ? ST_ILLEGAL : ST_ID;

                    if (!mem_error_i) begin
                        state_d = ST_ID;
                        ctrl_o.pc_we = 1'b1;
                        ctrl_o.ir_we = 1'b1;
                    end
                end else begin
                    state_d = ST_IF_RESP;
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
                if (mem_ready_i) begin
                    state_d = mem_error_i ? ST_ILLEGAL : ST_WB;
                end else begin
                    state_d = ST_LD;
                end

                mem_valid_o         = 1'b1;
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
                if (mem_ready_i) begin
                    state_d = mem_error_i ? ST_ILLEGAL : ST_IF_REQ;
                end else begin
                    state_d = ST_ST;
                end

                mem_valid_o         = 1'b1;
                ctrl_o.mem_addr_sel = MEM_ADDR_RESULT;
                ctrl_o.mem_we       = 1'b1;

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
                if (is_load) ctrl_o.result_sel = RESULT_LOAD_DATA_Q;
            end

            ST_ILLEGAL: begin
                state_d = ST_ILLEGAL;
                illegal_instr_o = 1'b1;
            end

            default: begin
                state_d = ST_ILLEGAL;
            end
        endcase

        if (illegal_instr || data_misaligned || addr_misaligned) begin
            state_d = ST_ILLEGAL;
            ctrl_o.pc_we  = 1'b0;
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
        end else begin
            state_q <= state_d;
        end
    end

    // Instruction legality check
    always_comb begin
        illegal_instr = (state_q == ST_ID);

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
    end

    // Instruction and data address alignment checks
    always_comb begin
        addr_misaligned = 1'b0;
        data_misaligned = 1'b0;

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

    assign trace_valid_o = ((state_q == ST_ST) && mem_valid_o && mem_ready_i && !mem_error_i) ||
                           ((state_q == ST_EX) && is_branch && !(take_branch && addr_misaligned)) ||
                           (state_q == ST_WB);

endmodule
