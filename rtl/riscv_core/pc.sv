module pc (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        trap_enter_i,
    input  logic [31:0] mtvec_i,
    input  logic        mret_i,
    input  logic [31:0] mepc_i,
    input  logic        pc_we_i,
    input  logic [31:0] next_pc_i,
    output logic [31:0] pc_o
);

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            pc_o <= '0;
        end else if (trap_enter_i) begin
            pc_o <= mtvec_i;
        end else if (mret_i) begin
            pc_o <= mepc_i;
        end else if (pc_we_i) begin
            pc_o <= next_pc_i;
        end
    end

endmodule
