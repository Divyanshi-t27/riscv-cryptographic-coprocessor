module present_key_schedule (
    input  [79:0] key_in,
    input  [4:0]  round_counter,
    output reg [79:0] key_out,
    output reg [63:0] round_key
);

    reg [79:0] temp_key;

    always @(*) begin

        /*
         * Step 1:
         * Rotate the 80-bit key left by 61 bits.
         *
         * Equivalent to:
         * temp_key = key_in[18:0] concatenated with key_in[79:19]
         */
        temp_key = {key_in[18:0], key_in[79:19]};

        /*
         * Step 2:
         * Apply PRESENT S-box to the most significant nibble
         * temp_key[79:76]
         */

        case (temp_key[79:76])

            4'h0: temp_key[79:76] = 4'hC;
            4'h1: temp_key[79:76] = 4'h5;
            4'h2: temp_key[79:76] = 4'h6;
            4'h3: temp_key[79:76] = 4'hB;
            4'h4: temp_key[79:76] = 4'h9;
            4'h5: temp_key[79:76] = 4'h0;
            4'h6: temp_key[79:76] = 4'hA;
            4'h7: temp_key[79:76] = 4'hD;
            4'h8: temp_key[79:76] = 4'h3;
            4'h9: temp_key[79:76] = 4'hE;
            4'hA: temp_key[79:76] = 4'hF;
            4'hB: temp_key[79:76] = 4'h8;
            4'hC: temp_key[79:76] = 4'h4;
            4'hD: temp_key[79:76] = 4'h7;
            4'hE: temp_key[79:76] = 4'h1;
            4'hF: temp_key[79:76] = 4'h2;

            default: temp_key[79:76] = 4'h0;

        endcase

        /*
         * Step 3:
         * XOR round counter into bits [19:15]
         */
        temp_key[19:15] = temp_key[19:15] ^ round_counter;

        /*
         * Step 4:
         * Output the updated 80-bit key
         */
        key_out = temp_key;

        /*
         * 64-bit round key used by AddRoundKey
         */
        round_key = key_in[79:16];

    end

endmodule