//-----------------------------------------------------------------------------
//  Module   : apb_gpio
//  Children : gpio
//
//  Register map:
//    0x000 INPUT           RO
//    0x004 OUTPUT          RW
//    0x008 OUTPUT_ENABLE   RW (1 = output, 0 = input/high impedance)
//    0x00c IRQ_RISE_ENABLE RW
//    0x010 IRQ_FALL_ENABLE RW
//    0x014 IRQ_STATUS      RW1C
//-----------------------------------------------------------------------------

module apb_gpio #(
    parameter int unsigned WIDTH = 32
) (
    input  logic             clk_i,
    input  logic             rst_ni,
    input  logic [WIDTH-1:0] gpio_i,
    output logic [WIDTH-1:0] gpio_o,
    output logic [WIDTH-1:0] gpio_oe_o,
    output logic             irq_o,
    apb_if.Slave cpl
);
    import gpio_reg_pkg::*;

    logic [31:0] output_q;
    logic [31:0] output_enable_q;
    logic [31:0] irq_rise_enable_q;
    logic [31:0] irq_fall_enable_q;
    logic [31:0] strobed_wdata;
    logic [WIDTH-1:0] input_value;
    logic [WIDTH-1:0] irq_status;
    logic [WIDTH-1:0] irq_clear;
    logic             access_done;
    logic             access_error;

    initial begin : check_apb_gpio
        if ((WIDTH == 0) || (WIDTH > 32))
            $fatal(1, "WIDTH must be between 1 and 32");
    end

    function automatic logic [31:0] merge_write(
        input logic [31:0] old_value,
        input logic [31:0] new_value,
        input logic [3:0]  strb
    );
        logic [31:0] result;
        result = old_value;
        for (int i = 0; i < 4; i++) begin
            if (strb[i])
                result[8*i +: 8] = new_value[8*i +: 8];
        end
        return result;
    endfunction

    always_comb begin
        cpl.prdata   = '0;
        access_error = 1'b0;

        if (cpl.psel) begin
            unique case (cpl.paddr[11:0])
                INPUT_OFFSET: begin
                    access_error            = cpl.pwrite;
                    cpl.prdata[WIDTH-1:0] = input_value;
                end
                OUTPUT_OFFSET:
                    cpl.prdata[WIDTH-1:0] = output_q[WIDTH-1:0];
                OUTPUT_ENABLE_OFFSET:
                    cpl.prdata[WIDTH-1:0] = output_enable_q[WIDTH-1:0];
                IRQ_RISE_ENABLE_OFFSET:
                    cpl.prdata[WIDTH-1:0] = irq_rise_enable_q[WIDTH-1:0];
                IRQ_FALL_ENABLE_OFFSET:
                    cpl.prdata[WIDTH-1:0] = irq_fall_enable_q[WIDTH-1:0];
                IRQ_STATUS_OFFSET:
                    cpl.prdata[WIDTH-1:0] = irq_status;
                default: access_error = 1'b1;
            endcase
        end
    end

    assign cpl.pready     = rst_ni;
    assign access_done    = cpl.psel && cpl.penable && cpl.pready;
    assign cpl.pslverr    = access_done && access_error;
    assign strobed_wdata  = merge_write('0, cpl.pwdata, cpl.pstrb);
    assign irq_clear      = (access_done && !access_error && cpl.pwrite &&
                             (cpl.paddr[11:0] == IRQ_STATUS_OFFSET))
                            ? strobed_wdata[WIDTH-1:0] : '0;

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            output_q          <= '0;
            output_enable_q   <= '0;
            irq_rise_enable_q <= '0;
            irq_fall_enable_q <= '0;
        end
        else if (access_done && !access_error && cpl.pwrite) begin
            unique case (cpl.paddr[11:0])
                OUTPUT_OFFSET:
                    output_q <= merge_write(output_q, cpl.pwdata, cpl.pstrb);
                OUTPUT_ENABLE_OFFSET:
                    output_enable_q <= merge_write(output_enable_q, cpl.pwdata, cpl.pstrb);
                IRQ_RISE_ENABLE_OFFSET:
                    irq_rise_enable_q <= merge_write(irq_rise_enable_q, cpl.pwdata, cpl.pstrb);
                IRQ_FALL_ENABLE_OFFSET:
                    irq_fall_enable_q <= merge_write(irq_fall_enable_q, cpl.pwdata, cpl.pstrb);
                default: ;
            endcase
        end
    end

    gpio #(
        .WIDTH              (WIDTH)
    ) u_gpio (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .gpio_i             (gpio_i),
        .gpio_o             (gpio_o),
        .gpio_oe_o          (gpio_oe_o),
        .output_value_i     (output_q[WIDTH-1:0]),
        .output_enable_i    (output_enable_q[WIDTH-1:0]),
        .input_value_o      (input_value),
        .irq_rise_enable_i  (irq_rise_enable_q[WIDTH-1:0]),
        .irq_fall_enable_i  (irq_fall_enable_q[WIDTH-1:0]),
        .irq_clear_i        (irq_clear),
        .irq_status_o       (irq_status),
        .irq_o              (irq_o)
    );

endmodule
