module present_key_reg (
    input        clk,
    input        reset,
    input  [79:0] key_in,
    output reg [79:0] key_out
);

    always @(posedge clk) begin

        if (reset)
            key_out <= 80'b0;
        else
            key_out <= key_in;

    end

endmodule