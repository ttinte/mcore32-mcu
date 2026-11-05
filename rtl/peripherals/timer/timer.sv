//-----------------------------------------------------------------------------
//  Module   : timer
//  Children : None
//
//  Description:
//     Bus-independent 32-bit down counter. Configuration inputs are intended
//     to be driven by registers implemented in the SoC integration layer.
//     A timeout produces a one-cycle pulse and optionally latches an IRQ.
//
//     One timer tick occurs every (prescaler_i + 1) input-clock cycles.
//     load_i has priority over counting. In periodic mode, expiration reloads
//     reload_i; in one-shot mode, the counter remains at zero.
//-----------------------------------------------------------------------------

module timer (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        enable_i,
    input  logic        periodic_i,
    input  logic        irq_enable_i,
    input  logic        load_i,
    input  logic        irq_clear_i,
    input  logic [15:0] prescaler_i,
    input  logic [31:0] reload_i,

    output logic [31:0] count_o,
    output logic        timeout_o,
    output logic        irq_o
);

    logic [31:0] count_q;
    logic [15:0] prescale_count_q;

    assign count_o = count_q;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            count_q          <= '0;
            prescale_count_q <= '0;
            timeout_o        <= 1'b0;
            irq_o            <= 1'b0;
        end
        else begin
            timeout_o <= 1'b0;

            if (irq_clear_i)
                irq_o <= 1'b0;

            if (load_i) begin
                count_q          <= reload_i;
                prescale_count_q <= '0;
            end
            else if (enable_i && (count_q != 0)) begin
                if (prescale_count_q == prescaler_i) begin
                    prescale_count_q <= '0;

                    if (count_q == 32'd1) begin
                        timeout_o <= 1'b1;
                        count_q   <= periodic_i ? reload_i : 32'd0;

                        if (irq_enable_i)
                            irq_o <= 1'b1;
                    end
                    else begin
                        count_q <= count_q - 32'd1;
                    end
                end
                else begin
                    prescale_count_q <= prescale_count_q + 16'd1;
                end
            end
            else begin
                prescale_count_q <= '0;
            end
        end
    end

endmodule
