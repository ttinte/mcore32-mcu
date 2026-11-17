//-----------------------------------------------------------------------------
//  Module   : apb_dht22
//
//  Register map:
//    0x000 COMMAND     WO  [0] start a DHT22 transaction
//    0x004 STATUS      RO  [0] busy, [1] valid, [2] checksum error, [3] timeout
//    0x008 TEMPERATURE RO  signed 0.1 degC
//    0x00c HUMIDITY    RO  unsigned 0.1 %RH
//-----------------------------------------------------------------------------

module apb_dht22 #(
    parameter int unsigned CLOCK_RATE = 70_000_000
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic dht_i,
    output logic dht_drive_low_o,
    apb_if.Slave cpl
);
    import dht22_reg_pkg::*;

    logic        core_busy;
    logic        core_done;
    logic        core_checksum_error;
    logic        core_timeout;
    logic [15:0] core_humidity;
    logic signed [15:0] core_temperature;
    logic        valid_q;
    logic        checksum_error_q;
    logic        timeout_q;
    logic        access_done;
    logic        access_error;
    logic        start_command;

    always_comb begin
        cpl.prdata = '0;
        access_error = 1'b0;
        if (cpl.psel) begin
            unique case (cpl.paddr[11:0])
                COMMAND_OFFSET: access_error = !cpl.pwrite ||
                                               (cpl.pstrb[0] && cpl.pwdata[0] && core_busy);
                STATUS_OFFSET: begin
                    access_error = cpl.pwrite;
                    cpl.prdata[0] = core_busy;
                    cpl.prdata[1] = valid_q;
                    cpl.prdata[2] = checksum_error_q;
                    cpl.prdata[3] = timeout_q;
                end
                TEMPERATURE_OFFSET: begin
                    access_error = cpl.pwrite;
                    cpl.prdata[15:0] = core_temperature;
                end
                HUMIDITY_OFFSET: begin
                    access_error = cpl.pwrite;
                    cpl.prdata[15:0] = core_humidity;
                end
                default: access_error = 1'b1;
            endcase
        end
    end

    assign cpl.pready = rst_ni;
    assign access_done = cpl.psel && cpl.penable && cpl.pready;
    assign cpl.pslverr = access_done && access_error;
    assign start_command = access_done && !access_error && cpl.pwrite &&
                           (cpl.paddr[11:0] == COMMAND_OFFSET) &&
                           cpl.pstrb[0] && cpl.pwdata[0];

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            valid_q <= 1'b0;
            checksum_error_q <= 1'b0;
            timeout_q <= 1'b0;
        end else begin
            if (start_command) begin
                valid_q <= 1'b0;
                checksum_error_q <= 1'b0;
                timeout_q <= 1'b0;
            end
            if (core_done) begin
                valid_q <= !core_checksum_error && !core_timeout;
                checksum_error_q <= core_checksum_error;
                timeout_q <= core_timeout;
            end
        end
    end

    dht22_master #(
        .CLOCK_RATE (CLOCK_RATE)
    ) u_dht22_master (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .start_i            (start_command),
        .dht_i              (dht_i),
        .dht_drive_low_o    (dht_drive_low_o),
        .busy_o             (core_busy),
        .done_o             (core_done),
        .checksum_error_o   (core_checksum_error),
        .timeout_o          (core_timeout),
        .humidity_o         (core_humidity),
        .temperature_o      (core_temperature)
    );

endmodule
