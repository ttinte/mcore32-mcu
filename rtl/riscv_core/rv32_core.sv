import rv32_pkg::*;

module rv32_core (
    input  logic        clk_i,
    input  logic        rst_ni,

    output logic        mem_valid_o,
    input  logic        mem_ready_i,
    input  logic        mem_error_i,
    output logic [31:0] mem_addr_o,
    output logic        mem_we_o,
    output logic [31:0] mem_wdata_o,
    output logic [3:0]  mem_wstrb_o,
    input  logic [31:0] mem_rdata_i,

    output exception_t  trap_o,
    output logic        trace_valid_o,
    output logic [31:0] trace_pc_o,
    output logic [31:0] trace_instr_o,
    output logic        trace_rf_we_o,
    output logic [4:0]  trace_rf_rd_o,
    output logic [31:0] trace_rf_wdata_o
);

    decode_ctrl_t ctrl;
    exception_t   trap;

    logic [31:0] pc;
    logic [31:0] load_data;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] imm_ext;
    logic [31:0] alu_result;
    alu_flags_t  alu_flags;

    logic        csr_valid;
    logic [31:0] csr_source;
    logic [31:0] csr_rdata;
    logic [31:0] csr_wdata;
    logic [31:0] mtvec;
    logic [31:0] mepc;

    logic [31:0] mem_addr;
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [31:0] result;

    logic [31:0] old_pc_q;
    logic [31:0] instr_q;
    logic [31:0] load_data_q;
    logic [31:0] rs1_data_q;
    logic [31:0] rs2_data_q;
    logic [31:0] alu_out_q;
    logic [31:0] csr_rdata_q;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            old_pc_q    <= '0;
            instr_q     <= '0;
            load_data_q <= '0;
            rs1_data_q  <= '0;
            rs2_data_q  <= '0;
            alu_out_q   <= '0;
            csr_rdata_q <= '0;
        end
        else begin
            old_pc_q    <= ctrl.ir_we ? pc          : old_pc_q;
            instr_q     <= ctrl.ir_we ? mem_rdata_i : instr_q;
            load_data_q <= load_data;
            rs1_data_q  <= rs1_data;
            rs2_data_q  <= rs2_data;
            alu_out_q   <= ctrl.alu_out_we ? alu_result : alu_out_q;
            csr_rdata_q <= csr_rdata;
        end
    end

    always_comb begin
        mem_addr  = pc;
        operand_a = pc;
        operand_b = 32'd4;
        result    = ctrl.pc_clear_lsb ? {alu_out_q[31:1], 1'b0} : alu_out_q;

        if (ctrl.op_a_sel == OP_A_OLD_PC) begin
            operand_a = old_pc_q;
        end else if (ctrl.op_a_sel == OP_A_RS1) begin
            operand_a = rs1_data_q;
        end

        if (ctrl.op_b_sel == OP_B_RS2) begin
            operand_b = rs2_data_q;
        end else if (ctrl.op_b_sel == OP_B_IMM) begin
            operand_b = imm_ext;
        end

        if (ctrl.result_sel == RESULT_LOAD_DATA_Q) begin
            result = load_data_q;
        end else if (ctrl.result_sel == RESULT_CSR_Q) begin
            result = csr_rdata_q;            
        end

        if (ctrl.mem_addr_sel == MEM_ADDR_RESULT) begin
            mem_addr = alu_out_q;
        end
    end

    control_unit u_control_unit (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .instr_i            (instr_q),
        .flags_i            (alu_flags),
        .ctrl_o             (ctrl),
        .mem_valid_o        (mem_valid_o),
        .mem_ready_i        (mem_ready_i),
        .mem_error_i        (mem_error_i),
        .fetch_pc_i         (pc),
        .instr_pc_i         (old_pc_q),
        .alu_result_i       (alu_out_q),
        .csr_valid_i        (csr_valid),
        .trap_o             (trap),
        .trace_valid_o      (trace_valid_o)
    );

    pc u_pc (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .trap_enter_i       (trap.valid),
        .mtvec_i            (mtvec),
        .mret_i             (ctrl.mret),
        .mepc_i             (mepc),
        .pc_we_i            (ctrl.pc_we),
        .next_pc_i          (result),
        .pc_o               (pc)
    );

    assign mem_addr_o  = mem_addr;
    assign mem_we_o    = ctrl.mem_we;

    lsu u_lsu (
        .addr_lsb_i         (mem_addr[1:0]),
        .we_i               (ctrl.mem_we),
        .load_op_i          (ctrl.load_op),
        .store_op_i         (ctrl.store_op),
        .mem_rdata_i        (mem_rdata_i),
        .load_data_o        (load_data),
        .store_data_i       (rs2_data_q),
        .mem_wdata_o        (mem_wdata_o),
        .mem_wstrb_o        (mem_wstrb_o)
    );

    regfile u_regfile (
        .clk_i              (clk_i),
        .we_i               (ctrl.reg_we),
        .rd_i               (instr_q[11:7]),
        .rs1_i              (instr_q[19:15]),
        .rs2_i              (instr_q[24:20]),
        .wr_data_i          (result),
        .rs1_data_o         (rs1_data),
        .rs2_data_o         (rs2_data)
    );

    imm_gen u_imm_gen (
        .imm_sel_i          (ctrl.imm_sel),
        .instr_i            (instr_q),
        .imm_ext_o          (imm_ext)
    );

    alu u_alu (
        .alu_op_i           (ctrl.alu_op),
        .operand_a_i        (operand_a),
        .operand_b_i        (operand_b),
        .alu_result_o       (alu_result),
        .alu_flags_o        (alu_flags)
    );

    always_comb begin
        csr_source = instr_q[14] ? {27'd0, instr_q[19:15]} : rs1_data_q;
        csr_wdata  = csr_source;

        if (ctrl.csr_op == CSR_RS) begin
            csr_wdata = csr_rdata_q | csr_source;
        end else if (ctrl.csr_op == CSR_RC) begin
            csr_wdata = csr_rdata_q & ~csr_source;
        end
    end

    csrfile u_csrfile (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .valid_o            (csr_valid),
        .addr_i             (instr_q[31:20]),
        .write_i            (ctrl.csr_we),
        .wdata_i            (csr_wdata),
        .rdata_o            (csr_rdata),
        .trap_enter_i       (trap.valid),
        .trap_i             (trap),
        .mret_i             (ctrl.mret),
        .mtvec_o            (mtvec),
        .mepc_o             (mepc)
    );

    assign trap_o           = trap;
    assign trace_pc_o       = old_pc_q;
    assign trace_instr_o    = instr_q;
    assign trace_rf_we_o    = ctrl.reg_we && (instr_q[11:7] != 5'd0);
    assign trace_rf_rd_o    = instr_q[11:7];
    assign trace_rf_wdata_o = result;

endmodule
