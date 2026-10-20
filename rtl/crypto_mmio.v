
module crypto_mmio (
    input clk,
    input resetn,
    input wr,

    input [4:0] widx,
    input [31:0] wdata,

    output reg [31:0] rdata,

    // Interface to the cryptographic core
    output reg mode,
    output reg start,
    output reg [127:0] key,
    output reg [127:0] pt,

    input [127:0] ct,
    input core_done,
    input core_busy
);

    reg done_l, done_q;

    always @(posedge clk) begin
        start <= 1'b0;
        done_q <= core_done;

        if (!resetn) begin
            mode   <= 1'b0;
            key    <= 128'b0;
            pt     <= 128'b0;
            done_l <= 1'b0;
            done_q <= 1'b0;
        end else begin
            if (core_done && !done_q)
                done_l <= 1'b1;

            if (wr) begin
                if (widx == 5'd0) begin
                    mode <= wdata[1];

                    if (wdata[0]) begin
                        start  <= 1'b1;
                        done_l <= 1'b0;
                    end
                end

                // Key words: most significant word first
                if (widx >= 5'd4 && widx <= 5'd7)
                    key[(7-widx)*32 +: 32] <= wdata;

                // Plaintext words: most significant word first
                if (widx >= 5'd8 && widx <= 5'd11)
                    pt[(11-widx)*32 +: 32] <= wdata;
            end
        end
    end

    always @(*) begin
        rdata = 32'h0;

        if (widx == 5'd1)
            rdata = {30'b0, done_l, core_busy};

        if (widx >= 5'd12 && widx <= 5'd15)
            rdata = ct[(15-widx)*32 +: 32];
    end

endmodule
