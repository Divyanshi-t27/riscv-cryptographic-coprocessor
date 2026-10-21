module present_sbox (
    input  [3:0] sbox_in,
    output reg  [3:0] sbox_out
);

    always @(*) begin
        case (sbox_in)

            4'h0: sbox_out = 4'hC;
            4'h1: sbox_out = 4'h5;
            4'h2: sbox_out = 4'h6;
            4'h3: sbox_out = 4'hB;
            4'h4: sbox_out = 4'h9;
            4'h5: sbox_out = 4'h0;
            4'h6: sbox_out = 4'hA;
            4'h7: sbox_out = 4'hD;
            4'h8: sbox_out = 4'h3;
            4'h9: sbox_out = 4'hE;
            4'hA: sbox_out = 4'hF;
            4'hB: sbox_out = 4'h8;
            4'hC: sbox_out = 4'h4;
            4'hD: sbox_out = 4'h7;
            4'hE: sbox_out = 4'h1;
            4'hF: sbox_out = 4'h2;

            default: sbox_out = 4'h0;

        endcase
    end

endmodule