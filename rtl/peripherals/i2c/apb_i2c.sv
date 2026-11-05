//-----------------------------------------------------------------------------
//  Module   : apb_i2c
//  Children : i2c_master
//
//  Register map:
//    0x000 ADDRESS    RW  [6:0] 7-bit slave address
//    0x004 TXDATA     RW  [7:0] transmit byte
//    0x008 RXDATA     RO  [7:0] most recently received byte
//    0x00c COMMAND    WO  [0] start, [1] read (0 = write)
//    0x010 STATUS     RW1C [0] busy (RO), [1] done, [2] ACK error,
//                            [3] arbitration lost
//    0x014 IRQ_ENABLE RW  [0] done, [1] ACK error, [2] arbitration lost
//-----------------------------------------------------------------------------

module apb_i2c #(
    parameter int unsigned CLOCK_RATE = 50_000_000,
    parameter int unsigned I2C_RATE   = 100_000
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic scl_i,
    input  logic sda_i,
    output logic scl_drive_low_o,
    output logic sda_drive_low_o,
    output logic irq_o,
    apb_if.Slave cpl
);
    import i2c_reg_pkg::*;

    logic [31:0] address_q;
    logic [31:0] txdata_q;
    logic [31:0] irq_enable_q;
    logic [7:0]  core_rx_data;
    logic [7:0]  rxdata_q;
    logic        core_busy;
    logic        core_done;
    logic        core_ack_error;
    logic        core_arbitration_lost;
    logic        done_pending_q;
    logic        ack_error_q;
    logic        arbitration_lost_q;
    logic        start_command;
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
                ADDRESS_OFFSET:
                    cpl.prdata[6:0] = address_q[6:0];
                TXDATA_OFFSET:
                    cpl.prdata[7:0] = txdata_q[7:0];
                RXDATA_OFFSET: begin
                    access_error    = cpl.pwrite;
                    cpl.prdata[7:0] = rxdata_q;
                end
                COMMAND_OFFSET: begin
                    access_error = !cpl.pwrite ||
                                   (cpl.pstrb[0] && cpl.pwdata[0] && core_busy);
                end
                STATUS_OFFSET: begin
                    cpl.prdata[0] = core_busy;
                    cpl.prdata[1] = done_pending_q;
                    cpl.prdata[2] = ack_error_q;
                    cpl.prdata[3] = arbitration_lost_q;
                end
                IRQ_ENABLE_OFFSET:
                    cpl.prdata[2:0] = irq_enable_q[2:0];
                default: access_error = 1'b1;
            endcase
        end
    end

    assign cpl.pready  = rst_ni;
    assign access_done = cpl.psel && cpl.penable && cpl.pready;
    assign cpl.pslverr = access_done && access_error;

    assign start_command = access_done && !access_error && cpl.pwrite &&
                           (cpl.paddr[11:0] == COMMAND_OFFSET) &&
                           cpl.pstrb[0] && cpl.pwdata[0];

    assign irq_o = (done_pending_q       && irq_enable_q[0]) ||
                   (ack_error_q          && irq_enable_q[1]) ||
                   (arbitration_lost_q   && irq_enable_q[2]);

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            address_q          <= '0;
            txdata_q           <= '0;
            irq_enable_q       <= '0;
            rxdata_q           <= '0;
            done_pending_q     <= 1'b0;
            ack_error_q        <= 1'b0;
            arbitration_lost_q <= 1'b0;
        end
        else begin
            if (access_done && !access_error && cpl.pwrite) begin
                unique case (cpl.paddr[11:0])
                    ADDRESS_OFFSET:
                        address_q <= merge_write(address_q, cpl.pwdata, cpl.pstrb);
                    TXDATA_OFFSET:
                        txdata_q <= merge_write(txdata_q, cpl.pwdata, cpl.pstrb);
                    IRQ_ENABLE_OFFSET:
                        irq_enable_q <= merge_write(irq_enable_q, cpl.pwdata, cpl.pstrb);
                    STATUS_OFFSET: begin
                        if (cpl.pstrb[0] && cpl.pwdata[1])
                            done_pending_q <= 1'b0;
                        if (cpl.pstrb[0] && cpl.pwdata[2])
                            ack_error_q <= 1'b0;
                        if (cpl.pstrb[0] && cpl.pwdata[3])
                            arbitration_lost_q <= 1'b0;
                    end
                    default: ;
                endcase
            end

            if (start_command) begin
                done_pending_q     <= 1'b0;
                ack_error_q        <= 1'b0;
                arbitration_lost_q <= 1'b0;
            end

            if (core_done) begin
                rxdata_q           <= core_rx_data;
                done_pending_q     <= 1'b1;
                ack_error_q        <= core_ack_error;
                arbitration_lost_q <= core_arbitration_lost;
            end
        end
    end

    i2c_master #(
        .CLOCK_RATE         (CLOCK_RATE),
        .I2C_RATE           (I2C_RATE)
    ) u_i2c_master (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .start_i            (start_command),
        .read_i             (cpl.pwdata[1]),
        .address_i          (address_q[6:0]),
        .tx_data_i          (txdata_q[7:0]),
        .rx_data_o          (core_rx_data),
        .busy_o             (core_busy),
        .done_o             (core_done),
        .ack_error_o        (core_ack_error),
        .arbitration_lost_o (core_arbitration_lost),
        .scl_i              (scl_i),
        .sda_i              (sda_i),
        .scl_drive_low_o    (scl_drive_low_o),
        .sda_drive_low_o    (sda_drive_low_o)
    );

endmodule
