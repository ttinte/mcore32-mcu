module pc (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        pc_we,
    input  logic [31:0] next_pc,
    output logic [31:0] pc_o
);

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            pc_o <= '0;
        end else if (pc_we) begin
            pc_o <= next_pc;
        end
    end

endmodule
