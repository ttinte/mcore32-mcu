//-----------------------------------------------------------------------------
//  Module   : apb_timer
//  Children : timer
//
//  Register map:
//    0x000 CTRL      RW  [0] enable, [1] periodic, [2] IRQ enable
//    0x004 PRESCALER RW  Timer tick divider minus one
//    0x008 RELOAD    RW  Counter reload value
//    0x00c VALUE     RO  Current counter value
//    0x010 STATUS    RW1C [0] IRQ pending, [1] timeout pulse (RO)
//    0x014 COMMAND   WO  [0] load RELOAD into the counter
//-----------------------------------------------------------------------------

module apb_timer (
    input  logic clk_i,
    input  logic rst_ni,
    output logic irq_o,
    apb_if.Slave cpl
);
    import timer_reg_pkg::*;

    logic [31:0] ctrl_q;
    logic [31:0] prescaler_q;
    logic [31:0] reload_q;
    logic [31:0] count;
    logic        timeout;
    logic        load;
    logic        irq_clear;
    logic        access_done;
    logic        access_error;

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
                CTRL_OFFSET: begin
                    cpl.prdata[2:0] = ctrl_q[2:0];
                end

                PRESCALER_OFFSET: begin
                    cpl.prdata[15:0] = prescaler_q[15:0];
                end

                RELOAD_OFFSET: begin
                    cpl.prdata = reload_q;
                end

                VALUE_OFFSET: begin
                    access_error = cpl.pwrite;
                    cpl.prdata   = count;
                end

                STATUS_OFFSET: begin
                    cpl.prdata[0] = irq_o;
                    cpl.prdata[1] = timeout;
                end

                COMMAND_OFFSET: begin
                    access_error = !cpl.pwrite;
                end

                default: access_error = 1'b1;
            endcase
        end
    end

    assign cpl.pready  = rst_ni;
    assign access_done = cpl.psel && cpl.penable && cpl.pready;
    // Invalid offsets and forbidden directions complete with an error and
    // never update the counter or its configuration registers.
    assign cpl.pslverr = access_done && access_error;

    assign load = access_done && !access_error && cpl.pwrite &&
                  (cpl.paddr[11:0] == COMMAND_OFFSET) &&
                  cpl.pstrb[0] && cpl.pwdata[0];

    assign irq_clear = access_done && !access_error && cpl.pwrite &&
                       (cpl.paddr[11:0] == STATUS_OFFSET) &&
                       cpl.pstrb[0] && cpl.pwdata[0];

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            ctrl_q      <= '0;
            prescaler_q <= '0;
            reload_q    <= '0;
        end
        else if (access_done && !access_error && cpl.pwrite) begin
            unique case (cpl.paddr[11:0])
                CTRL_OFFSET:
                    ctrl_q <= merge_write(ctrl_q, cpl.pwdata, cpl.pstrb);
                PRESCALER_OFFSET:
                    prescaler_q <= merge_write(prescaler_q, cpl.pwdata, cpl.pstrb);
                RELOAD_OFFSET:
                    reload_q <= merge_write(reload_q, cpl.pwdata, cpl.pstrb);
                default: ;
            endcase
        end
    end

    timer u_timer (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .enable_i           (ctrl_q[0]),
        .periodic_i         (ctrl_q[1]),
        .irq_enable_i       (ctrl_q[2]),
        .load_i             (load),
        .irq_clear_i        (irq_clear),
        .prescaler_i        (prescaler_q[15:0]),
        .reload_i           (reload_q),
        .count_o            (count),
        .timeout_o          (timeout),
        .irq_o              (irq_o)
    );

endmodule
