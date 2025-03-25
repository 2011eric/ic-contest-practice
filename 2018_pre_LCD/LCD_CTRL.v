module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input clk;
input reset;
input [3:0] cmd;
input cmd_valid;
input [7:0] IROM_Q;
output logic IROM_rd;
output logic [5:0] IROM_A;
output logic IRAM_valid;
output logic [7:0] IRAM_D;
output logic [5:0] IRAM_A;
output busy;
output reg done;


localparam DATA_WIDTH = 8;
localparam IMG_WIDTH = 8;
typedef logic [DATA_WIDTH-1:0] pixel_t;
typedef pixel_t [0:IMG_WIDTH-1][0:IMG_WIDTH-1] map_t;
typedef logic [$clog2(IMG_WIDTH)-1:0] index_t;
typedef struct packed {
    index_t y;
    index_t x;
} coord_t;

map_t data_r, data_w;

typedef enum logic [3:0] {
    IDLE,
    WRITE_RAM,
    FIND_MAX,
    FIND_MIN,
    FING_AVG,
    DO_ROT_COUNTER,
    DO_ROT_CLOCK,
    READ_ROM
} state_e;

typedef enum logic [3:0] {
    WRITE,
    SHIFT_UP,
    SHIFT_DOWN,
    SHIFT_LEFT,
    SHIFT_RIGHT,
    MAX,
    MIN,
    AVG,
    ROT_COUNTER,
    ROT_CLOCK,
    MIRROR_X,
    MIRROR_Y
} op_e;

/*
0 1
2 3

cclkw
1 3
0 2

clkw
2 0
3 1


*/

state_e state_r, state_w;
coord_t pos_r, pos_w;

coord_t op_point_r, op_point_w;
assign busy = (state_r != IDLE);
logic [1:0] cnt4_r, cnt4_w;
logic done_r, done_w;
pixel_t pixel_r[0:3], pixel_w[0:3];


assign done = done_r;
assign pixel_r[0] = data_r[op_point_r.y-1][op_point_r.x-1];
assign pixel_r[1] = data_r[op_point_r.y-1][op_point_r.x-0];
assign pixel_r[2] = data_r[op_point_r.y-0][op_point_r.x-1];
assign pixel_r[3] = data_r[op_point_r.y-0][op_point_r.x-0];


logic [$bits(pixel_t)+2-1:0] tmp_pixel_r, tmp_pixel_w;

op_e mycmd;
assign mycmd = op_e'(cmd);
function pixel_t FindMin;
input pixel_t a, b, c, d;
pixel_t temp_min;
begin
    temp_min = (a<b) ? a : b;
    temp_min = (c<temp_min) ? c : temp_min;
    temp_min = (d<temp_min) ? d : temp_min;
    FindMin = temp_min;
end

endfunction

function pixel_t FindMax;
input pixel_t a, b, c, d;
pixel_t temp_max;
begin
    temp_max = (a>b) ? a : b;
    temp_max = (c>temp_max) ? c : temp_max;
    temp_max = (d>temp_max) ? d : temp_max;
    FindMax = temp_max;
end

endfunction


always_comb begin : comb_logic
    state_w = state_r;
    pos_w = pos_r;
    data_w = data_r;
    done_w = 0;
    pixel_w = pixel_r;

    IROM_rd = (state_r == READ_ROM);
    IROM_A = pos_r;
    IRAM_valid = (state_r == WRITE_RAM);
    IRAM_D = data_r[pos_r.y][pos_r.x];
    IRAM_A = pos_r;

    cnt4_w = cnt4_r;
    tmp_pixel_w = tmp_pixel_r;
    op_point_w = op_point_r;
    unique case(state_r)
        READ_ROM: begin
            pos_w = pos_r + 1;
            data_w[pos_r.y][pos_r.x] = IROM_Q;
            if(pos_r == IMG_WIDTH**2-1) begin
                state_w = IDLE;
            end
        end
        IDLE:begin
            if (cmd_valid) begin
                $display($time, " cmd: %d", mycmd);
                for(int i = 0; i < IMG_WIDTH; i++) begin
                    for(int j = 0; j < IMG_WIDTH; j++) begin
                        $write("%3h ", data_r[i][j]);
                    end
                    $write("\n");
                end
                unique case (mycmd)
                    WRITE: begin
                        state_w = WRITE_RAM;
                        pos_w = 0;
                    end
                    SHIFT_UP: begin
                        if (op_point_r.y > 1) begin
                            op_point_w.y = op_point_r.y - 1;end
                    end
                    SHIFT_DOWN: begin
                        if (op_point_r.y < IMG_WIDTH-1) begin
                            op_point_w.y = op_point_r.y + 1;end
                    end
                    SHIFT_RIGHT: begin
                        if (op_point_r.x < IMG_WIDTH-1) begin
                            op_point_w.x = op_point_r.x + 1;end
                    end
                    SHIFT_LEFT: begin
                        if (op_point_r.x > 1) begin
                            op_point_w.x = op_point_r.x - 1;end
                    end
                    MAX: begin
                        // state_w = FIND_MAX;
                        // cnt4_w = 1;
                        // tmp_pixel_w = pixel_r[0];
                        pixel_w[0] = FindMax(pixel_r[0], pixel_r[1], pixel_r[2], pixel_r[3]);
                        pixel_w[1] = FindMax(pixel_r[0], pixel_r[1], pixel_r[2], pixel_r[3]);
                        pixel_w[2] = FindMax(pixel_r[0], pixel_r[1], pixel_r[2], pixel_r[3]);
                        pixel_w[3] = FindMax(pixel_r[0], pixel_r[1], pixel_r[2], pixel_r[3]);
                    end
                    MIN: begin
                        // state_w = FIND_MIN;
                        // cnt4_w = 1;
                        // tmp_pixel_w = pixel_r[0];
                        pixel_w[0] = FindMin(pixel_r[0], pixel_r[1], pixel_r[2], pixel_r[3]);
                        pixel_w[1] = FindMin(pixel_r[0], pixel_r[1], pixel_r[2], pixel_r[3]);
                        pixel_w[2] = FindMin(pixel_r[0], pixel_r[1], pixel_r[2], pixel_r[3]);
                        pixel_w[3] = FindMin(pixel_r[0], pixel_r[1], pixel_r[2], pixel_r[3]);
                    end
                    AVG: begin
                        tmp_pixel_w = (pixel_r[0] + pixel_r[1] + pixel_r[2] + pixel_r[3]) >> 2;
                        for (int i = 0; i < 4; i++)begin
                            pixel_w[i] = tmp_pixel_w;end
                    end
                    ROT_COUNTER: begin
                        pixel_w[0] = pixel_r[1];
                        pixel_w[1] = pixel_r[3];
                        pixel_w[2] = pixel_r[0];
                        pixel_w[3] = pixel_r[2];
                    end
                    ROT_CLOCK: begin
                        pixel_w[0] = pixel_r[2];
                        pixel_w[1] = pixel_r[0];
                        pixel_w[2] = pixel_r[3];
                        pixel_w[3] = pixel_r[1];
                    end
                    MIRROR_Y: begin
                        state_w = IDLE;
                        pixel_w[0] = pixel_r[1];
                        pixel_w[1] = pixel_r[0];
                        pixel_w[2] = pixel_r[3];
                        pixel_w[3] = pixel_r[2];
                    end
                    MIRROR_X: begin
                        state_w = IDLE;
                        pixel_w[0] = pixel_r[2];
                        pixel_w[1] = pixel_r[3];
                        pixel_w[2] = pixel_r[0];
                        pixel_w[3] = pixel_r[1];
                    end
                endcase

            end
        end
        FIND_MAX: begin
            cnt4_w = cnt4_r + 1;
            tmp_pixel_w =  (pixel_r[cnt4_r] > tmp_pixel_r) ? pixel_r[cnt4_r] : tmp_pixel_r;
            if (cnt4_r == 2'd3) begin
                state_w = IDLE;
                for (int i = 0; i < 4; i++)
                    pixel_w[i] = tmp_pixel_w;
            end
        end
        FIND_MIN: begin
            cnt4_w = cnt4_r + 1;
            tmp_pixel_w =  (pixel_r[cnt4_r] < tmp_pixel_r) ? pixel_r[cnt4_r] : tmp_pixel_r;
            if (cnt4_r == 2'd3) begin
                state_w = IDLE;
                for (int i = 0; i < 4; i++)
                    pixel_w[i] = tmp_pixel_w;
            end
        end
        WRITE_RAM: begin
            pos_w = pos_r + 1;
            pixel_w = pixel_r;
            op_point_w = op_point_r;
            if (pos_r == IMG_WIDTH**2-1) begin
                state_w = IDLE;
                done_w = 1;
            end
        end
    endcase

    if(state_r != READ_ROM) begin
        data_w[op_point_r.y-1][op_point_r.x-1] = pixel_w[0];
        data_w[op_point_r.y-1][op_point_r.x-0] = pixel_w[1];
        data_w[op_point_r.y-0][op_point_r.x-1] = pixel_w[2];
        data_w[op_point_r.y-0][op_point_r.x-0] = pixel_w[3];
    end
end

always_ff @(posedge clk, posedge reset) begin
    if (reset) begin
        data_r <= '{default:'0};
        pos_r <= '0;
        op_point_r <= {3'd4, 3'd4};
        cnt4_r <= 0;
        tmp_pixel_r <= 0;
        done_r <= 0;
        state_r <= READ_ROM;
    end else begin
        data_r <= data_w;
        pos_r <= pos_w;
        op_point_r <= op_point_w;
        cnt4_r <= cnt4_w;
        tmp_pixel_r <= tmp_pixel_w;
        done_r <= done_w;
        state_r <= state_w;
    end
end
endmodule



