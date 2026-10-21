module present_state_reg (
    input         clk,
    input         reset,
    input  [63:0] state_in,
    output reg [63:0] state_out
);

    always @(posedge clk) begin
        if (reset)
            state_out <= 64'b0;
        else
            state_out <= state_in;
    end

endmodule