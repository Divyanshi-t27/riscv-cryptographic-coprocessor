module present_pbox (
    input  [63:0] pbox_in,
    output reg  [63:0] pbox_out
);

    integer i;
    integer position;

    always @(*) begin

        pbox_out = 64'b0;

        for (i = 0; i < 63; i = i + 1) begin
            position = (16 * i) % 63;
            pbox_out[position] = pbox_in[i];
        end

        // Bit 63 remains at position 63
        pbox_out[63] = pbox_in[63];

    end

endmodule