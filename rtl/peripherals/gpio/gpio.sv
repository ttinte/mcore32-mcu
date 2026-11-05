//-----------------------------------------------------------------------------
//  Module   : gpio
//  Children : None
//
//  Description:
//     Bus-independent GPIO core with synchronized inputs, separate output and
//     output-enable controls, and per-pin rising/falling-edge interrupts.
//     Interrupt status remains set until the corresponding irq_clear_i bit is
//     asserted. External bidirectional buffers belong in the FPGA top level.
//-----------------------------------------------------------------------------

module gpio #(
    parameter int unsigned WIDTH = 32
) (
    input  logic                 clk_i,
    input  logic                 rst_ni,

    input  logic [WIDTH-1:0]     gpio_i,
    output logic [WIDTH-1:0]     gpio_o,
    output logic [WIDTH-1:0]     gpio_oe_o,

    input  logic [WIDTH-1:0]     output_value_i,
    input  logic [WIDTH-1:0]     output_enable_i,
    output logic [WIDTH-1:0]     input_value_o,

    input  logic [WIDTH-1:0]     irq_rise_enable_i,
    input  logic [WIDTH-1:0]     irq_fall_enable_i,
    input  logic [WIDTH-1:0]     irq_clear_i,
    output logic [WIDTH-1:0]     irq_status_o,
    output logic                 irq_o
);

    initial begin : check_gpio
        if (WIDTH == 0)
            $fatal(1, "WIDTH must be greater than zero");
    end

    logic [WIDTH-1:0] input_meta_q;
    logic [WIDTH-1:0] input_sync_q;
    logic [WIDTH-1:0] input_prev_q;
    logic [WIDTH-1:0] rise_event;
    logic [WIDTH-1:0] fall_event;
    logic [WIDTH-1:0] irq_event;

    assign gpio_o        = output_value_i;
    assign gpio_oe_o     = output_enable_i;
    assign input_value_o = input_sync_q;

    assign rise_event = input_sync_q & ~input_prev_q;
    assign fall_event = ~input_sync_q & input_prev_q;
    assign irq_event  = (rise_event & irq_rise_enable_i) |
                        (fall_event & irq_fall_enable_i);
    assign irq_o      = |irq_status_o;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            input_meta_q  <= '0;
            input_sync_q  <= '0;
            input_prev_q  <= '0;
            irq_status_o  <= '0;
        end
        else begin
            input_meta_q <= gpio_i;
            input_sync_q <= input_meta_q;
            input_prev_q <= input_sync_q;
            irq_status_o <= (irq_status_o & ~irq_clear_i) | irq_event;
        end
    end

endmodule
