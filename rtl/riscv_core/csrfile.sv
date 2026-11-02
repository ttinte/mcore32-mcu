import rv32_pkg::*;

module csrfile (
    input  logic        clk_i,
    input  logic        rst_ni,

    output logic        valid_o,
    input  logic [11:0] addr_i,
    input  logic        write_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic        trap_enter_i,
    input  exception_t  trap_i,
    input  logic        mret_i,
    output logic [31:0] mtvec_o,
    output logic [31:0] mepc_o
);

    localparam logic [11:0]
        CSR_MSTATUS = 12'h300,
        CSR_MTVEC   = 12'h305,
        CSR_MEPC    = 12'h341,
        CSR_MCAUSE  = 12'h342,
        CSR_MTVAL   = 12'h343;

    logic [31:0] mstatus_q, mstatus_d;
    logic [31:0] mtvec_q,   mtvec_d;
    logic [31:0] mepc_q,    mepc_d;
    logic [31:0] mcause_q,  mcause_d;
    logic [31:0] mtval_q,   mtval_d;

    always_comb begin
        valid_o = 1'b1;
        rdata_o = '0;

        unique case (addr_i)
            CSR_MSTATUS: rdata_o = mstatus_q;
            CSR_MTVEC:   rdata_o = mtvec_q;
            CSR_MEPC:    rdata_o = mepc_q;
            CSR_MCAUSE:  rdata_o = mcause_q;
            CSR_MTVAL:   rdata_o = mtval_q;
            default:     valid_o = 1'b0;
        endcase
    end

    always_comb begin
        mstatus_d = mstatus_q;
        mtvec_d   = mtvec_q;
        mepc_d    = mepc_q;
        mcause_d  = mcause_q;
        mtval_d   = mtval_q;

        if (trap_enter_i) begin
            mstatus_d[7] = mstatus_q[3];
            mstatus_d[3] = 1'b0;
            mepc_d       = {trap_i.epc[31:2], 2'd0};
            mcause_d     = {28'b0, trap_i.cause};
            mtval_d      = trap_i.tval;
        end
        else if (mret_i) begin
            mstatus_d[3] = mstatus_q[7];
            mstatus_d[7] = 1'b1;
        end
        else if (write_i) begin
            unique case (addr_i)
                CSR_MSTATUS: mstatus_d = (wdata_i & 32'h0000_0088) | 32'h0000_1800;
                CSR_MTVEC:   mtvec_d   = {wdata_i[31:2], 2'b00};
                CSR_MEPC:    mepc_d    = {wdata_i[31:2], 2'b00};
                CSR_MCAUSE:  mcause_d  = wdata_i;
                CSR_MTVAL:   mtval_d   = wdata_i;
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            mstatus_q <= 32'h0000_1800;
            mtvec_q   <= '0;
            mepc_q    <= '0;
            mcause_q  <= '0;
            mtval_q   <= '0;
        end else begin
            mstatus_q <= mstatus_d;
            mtvec_q   <= mtvec_d;
            mepc_q    <= mepc_d;
            mcause_q  <= mcause_d;
            mtval_q   <= mtval_d;
        end
    end

    assign mtvec_o = mtvec_q;
    assign mepc_o  = mepc_q;

endmodule
