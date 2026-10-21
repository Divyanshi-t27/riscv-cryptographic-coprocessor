module present_controller (
    input        clk,
    input        reset,
    input        start,

    input  [4:0] round_counter,

    output reg load_enable,
    output reg initial_key_enable,
    output reg sbox_enable,
    output reg pbox_enable,
    output reg key_update_enable,
    output reg round_key_enable,
    output reg final_key_enable,
    output reg counter_enable,
    output reg done
);

    reg [3:0] state;
    reg [3:0] next_state;

    parameter IDLE        = 4'd0;
    parameter LOAD        = 4'd1;
    parameter INITIAL_KEY = 4'd2;
    parameter SBOX        = 4'd3;
    parameter PBOX        = 4'd4;
    parameter KEY_UPDATE  = 4'd5;
    parameter CHECK       = 4'd6;
    parameter ROUND_KEY   = 4'd7;
    parameter FINAL_KEY   = 4'd8;
    parameter DONE        = 4'd9;


    //========================================================
    // STATE REGISTER
    //========================================================

    always @(posedge clk) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end


    //========================================================
    // NEXT STATE
    //========================================================

    always @(*) begin

        next_state = IDLE;

        case (state)

            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end

            LOAD:
                next_state = INITIAL_KEY;

            INITIAL_KEY:
                next_state = SBOX;

            SBOX:
                next_state = PBOX;

            PBOX:
                next_state = KEY_UPDATE;

            KEY_UPDATE:
                next_state = CHECK;

            CHECK: begin

                /*
                 * After KEY_UPDATE:
                 *
                 * counter = 1  -> K2 generated
                 * counter = 2  -> K3 generated
                 * ...
                 * counter = 30 -> K31 generated
                 * counter = 31 -> K32 generated
                 */

                if (round_counter < 5'd31)
                    next_state = ROUND_KEY;
                else
                    next_state = FINAL_KEY;

            end

            ROUND_KEY:
                next_state = SBOX;

            FINAL_KEY:
                next_state = DONE;

            DONE:
                next_state = IDLE;

            default:
                next_state = IDLE;

        endcase

    end


    //========================================================
    // OUTPUT LOGIC
    //========================================================

    always @(*) begin

        load_enable        = 1'b0;
        initial_key_enable = 1'b0;
        sbox_enable        = 1'b0;
        pbox_enable        = 1'b0;
        key_update_enable  = 1'b0;
        round_key_enable   = 1'b0;
        final_key_enable   = 1'b0;
        counter_enable     = 1'b0;
        done               = 1'b0;

        case (state)

            LOAD:
                load_enable = 1'b1;

            INITIAL_KEY:
                initial_key_enable = 1'b1;

            SBOX:
                sbox_enable = 1'b1;

            PBOX:
                pbox_enable = 1'b1;

            KEY_UPDATE: begin
                key_update_enable = 1'b1;
                counter_enable    = 1'b1;
            end

            ROUND_KEY:
                round_key_enable = 1'b1;

            FINAL_KEY:
                final_key_enable = 1'b1;

            DONE:
                done = 1'b1;

        endcase

    end

endmodule