
module iterator #(parameter N = 16) (
	input clk,
	input rst,
	input step,
	output logic [$clog2(N)-1:0] x,
	output logic [$clog2(N)-1:0] y,
	output logic done
);

	assign done = (x == 13) && (y == 13);

	always_ff @(posedge clk) begin
		if (rst) begin
			x <= 4'd2;
			y <= 4'd2;
		end else begin
			if (step) begin
				if (x == 13) begin
					x <= 4'd2;
					if (y == 13) begin
						y <= 4'd2;
					end else begin
						y <= y + 1;
					end
				end else begin
					x <= x + 1;
				end
			end
		end
	end

endmodule


module LASER (
	input CLK,
	input RST,
	input [3:0] X,
	input [3:0] Y,
	output reg [3:0] C1X,
	output reg [3:0] C1Y,
	output reg [3:0] C2X,
	output reg [3:0] C2Y,
	output reg DONE
);

typedef enum logic[2:0] {S_INPUT, S_ITER, S_CENTER, S_COUNT, S_OUT} state_e;
typedef struct packed {
	logic [3:0] x;
	logic [3:0] y;
} cord_t;

localparam NUM_TARGET = 40;
localparam N = 16;
localparam NUM_ITER = 10;
//{(0, 1), (1, 2), (0, 4), (2, 1), (4, 0), (0, 0), (3, 1), (1, 1), (0, 3), (2, 0), (3, 0), (2, 3), (0, 2), (2, 2), (1, 0), (3, 2), (1, 3)}
// parameter offset_map_x = {
// 	0, 1, 0, 2, 4, 0, 3, 1, 0, 2, 3, 2, 0, 2, 1, 3, 1
// };
// parameter offset_map_y = {
// 	1, 2, 4, 1, 0, 0, 1, 1, 3, 0, 0, 3, 2 ,2, 0, 2, 3
// };

state_e state_r, state_w;

cord_t target_r [0:NUM_TARGET-1];
cord_t target_w [0:NUM_TARGET-1];

logic [5:0] cnt_r, cnt_w;
logic [$clog2(NUM_TARGET)-1:0] t_cnt_r, t_cnt_w;


logic done_r, done_w;
cord_t c1_r, c1_w;
cord_t c2_r, c2_w;

cord_t iter;
// logic [8:0] distance_square;

logic [5:0] max_cover_r, max_cover_w;
logic [5:0] temp_cover_r, temp_cover_w;

// output assignmen
assign DONE = done_r;
assign {C1X, C1Y} = c1_r;
assign {C2X, C2Y} = c2_r;


// iterator connection
logic iter_clear;
logic iter_step;
logic iter_done;
iterator #(
    .N        (16)
) u_iterator (
    .clk      (CLK),
    .rst      (RST),
    .step     (iter_step),
    .x        (iter.x),
    .y        (iter.y),
    .done     (iter_done)
);

function in_circle;
	input cord_t c1;
	input cord_t current;
	logic signed [4:0] dist_x, dist_y;
	begin
		dist_x = signed'({1'b0,c1.x}) - signed'({1'b0, current.x});
		dist_y =signed'({1'b0,c1.y}) - signed'({1'b0, current.y});
		// $display("dist_x: %d, dist_y: %d", dist_x, dist_y);
		case(dist_x)
			5'sd0: in_circle = ( dist_y <= 4 && dist_y >= -4);
			5'sd1: in_circle = ( dist_y <= 3 && dist_y >= -3);
			5'sd2: in_circle = ( dist_y <= 3 && dist_y >= -3);
			5'sd3: in_circle = ( dist_y <= 2 && dist_y >= -2);
			5'sd4: in_circle = ( dist_y == 0);
			-5'sd1: in_circle = ( dist_y <= 3 && dist_y >= -3);
			-5'sd2: in_circle = ( dist_y <= 3 && dist_y >= -3);
			-5'sd3: in_circle = ( dist_y <= 2 && dist_y >= -2);
			-5'sd4: in_circle = ( dist_y == 0);
			default: in_circle = '0;
		endcase
	end
endfunction

// (x-4, y-4) (x+4, y-4)
// (x-4, y+4) (x+4, y+4)



// findmax_fix2
//	covered
	// for (x, y) in map
	// 	if !covered(x,y) &&
// findmax_fix2(c1, c1)
// while (!cover)
// findmax_fix2(c1, c1)
// swap(c1, c2)


// 1. decide 2rd point center -> (16*16)*(40)

// typedef struct packed {
// 	logic in_c1;
// 	logic in_c2;
// } covered_t;

// covered_t covered_map_r [0:NUM_TARGET-1];
// covered_t covered_map_w [0:NUM_TARGET-1];

always_comb begin : state_logic
	state_w = state_r;
	cnt_w = cnt_r;
	t_cnt_w = t_cnt_r;
	target_w = target_r;

	c1_w = c1_r;
	c2_w = c2_r;
	done_w = '0;
	iter_step = 0;
	iter_clear = 0;
	max_cover_w = max_cover_r;
	temp_cover_w = temp_cover_r;

	case (state_r)
		S_INPUT: begin
			cnt_w = cnt_r + 1'b1;
			target_w[cnt_r] = {X, Y};
			state_w = state_r;
			if(cnt_r == NUM_TARGET-1) begin
				cnt_w = 0;
				t_cnt_w = '0;
				state_w = S_ITER;
			end else begin
				cnt_w = cnt_r + 1'b1;
			end
		end
		S_ITER: begin
			// swap c1, c2
			c1_w = c2_r;
			c2_w = c1_r;

			cnt_w = cnt_r + 1'b1;
			t_cnt_w = 0;
			state_w = S_COUNT;

			// end
			if(cnt_r == NUM_ITER) begin
				state_w = S_OUT;
			end
		end
		S_CENTER: begin
			state_w = S_COUNT;
			t_cnt_w = 0;
			temp_cover_w = 0;
			c2_w = c2_r;
			max_cover_w = max_cover_r;
			if(temp_cover_r >= max_cover_r) begin
				max_cover_w = temp_cover_r;
				c2_w = iter;
			end

			if (iter_done) begin
				state_w = S_ITER;
			end
			iter_step = 1;
		end
		S_COUNT: begin
			t_cnt_w = t_cnt_r + 1'b1;
			// target in circle1 or target in iterated_center circle
			// if ( in_circle( ((c1_r.x==0 && c1_r.y==0) ? iter : c1_r) , target_r[t_cnt_r]) || in_circle(iter, target_r[t_cnt_r]) ) begin
			if ( in_circle( c1_r , target_r[t_cnt_r]) || in_circle(iter, target_r[t_cnt_r]) ) begin
				temp_cover_w = temp_cover_r + 1'b1;
			end
			state_w = state_r;
			if (t_cnt_r == NUM_TARGET-1) begin
				state_w = S_CENTER;
			end
		end
		S_OUT: begin
			state_w = S_INPUT;
			done_w = 1'b1;
		end
		default: begin
		end
	endcase
end





always_ff @(posedge CLK) begin
	if (RST) begin
		state_r <= S_INPUT;
		target_r <= '{default:0};
		cnt_r[5:0] <= '0;
		// cnt_r[6] <= 0;
		// cnt_r[7] <= 0;
		t_cnt_r <= '0;
		done_r <= '0;
		c1_r <= '0;
		c2_r <= '0;
		max_cover_r <= 0;
		temp_cover_r <= 0;
	end else begin
		state_r <= state_w;
		target_r <= target_w;
		cnt_r[5:0] <= cnt_w[5:0];
		// cnt_r[6] <= cnt_w[6];
		// cnt_r[7] <= cnt_w[7];
		t_cnt_r <= t_cnt_w;
		done_r <= done_w;
		c1_r <= c1_w;
		c2_r <= c2_w;
		max_cover_r <= max_cover_w;
		temp_cover_r <= temp_cover_w;
	end
end

endmodule


