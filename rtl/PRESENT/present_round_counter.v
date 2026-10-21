module present_round_counter (
    input       clk,
    input       reset,
    input       enable,
    output reg [4:0] round_counter
);

    always @(posedge clk) begin

        if (reset)
            round_counter <= 5'd0;

        else if (enable)
            round_counter <= round_counter + 5'd1;

    end

endmodule