`timescale 1ns/1ps

module  CONV(
	input		clk,
	input		reset,
	output	reg	busy,
	input		ready,

	output  reg	[11:0]	iaddr,
	input		[19:0]	idata,	    // 4 bit integer + 16 bit decimal

	output	reg 		cwr,		// write signal
	output  reg	[11:0]	caddr_wr,
	output  reg	[19:0] 	cdata_wr,

	output	reg 		crd,        // read signal
	output  reg	[11:0] 	caddr_rd,
	input		[19:0] 	cdata_rd,

	output reg	[2:0] 	csel
);

localparam IMG_WIDTH = 64;
localparam INT_WIDTH = 4, FRAC_WIDTH = 16;
localparam DATA_WIDTH = INT_WIDTH + FRAC_WIDTH;
localparam COORD_WIDTH = $clog2(IMG_WIDTH);

localparam MUL_WIDTH = DATA_WIDTH + DATA_WIDTH;
localparam CONV_WIDTH = MUL_WIDTH + $clog2(9);
localparam ACC_WIDTH = CONV_WIDTH + 1;





parameter bit signed [19:0] kernel [3][3]= '{
	'{20'h0A89E,
	20'h092D5,
	20'h06d43},

	'{20'h01004,
	20'hF8F71,
	20'hF6E54},

	'{20'hFA6D7,
	20'hFC834,
	20'hFAC19}
};

localparam [DATA_WIDTH-1:0] bias = 20'h01310;


typedef struct packed {
	logic [COORD_WIDTH-1:0] y, x;
} index_t;

typedef struct packed {
	logic signed [INT_WIDTH-1:0] i;
	logic [FRAC_WIDTH-1:0] f;
} pixel_t;

typedef enum logic [2:0] {
	S_IDLE,
	S_CONV,
	S_MAXPOOL,
	S_BUBBLE,
	S_BUBBLE2,
	S_CONV_INNER,
	S_MAXPOOL_INNER
 } state_e;

 typedef enum logic [2:0] {
	MEM_NONE = 3'b000,
	MEM_LAYER0 = 3'b001,
	MEM_LAYER1 = 3'b011
 } mem_sel_e;

state_e state_r, state_w;

logic [7:0] cnt_r, cnt_w;
logic signed [ACC_WIDTH-1:0] acc_r, acc_w;
logic signed [ACC_WIDTH-1:0] acc_adder_result;


/* output registers */
logic busy_r, busy_w;
logic [11:0] iaddr_r, iaddr_w;
logic cwr_r, cwr_w;
logic [11:0] caddr_wr_r, caddr_wr_w;
pixel_t cdata_wr_r, cdata_wr_w;
logic crd_r, crd_w;
logic [11:0] caddr_rd_r, caddr_rd_w;
logic [2:0] csel_r, csel_w;




index_t input_pos_r, input_pos_w;

logic iter_step;
index_t iter_pos;
logic iter_done;
iterator #(
    .N       (IMG_WIDTH)
) u_iterator_conv (
    .clk     (clk),
    .rst     (reset),
    .step    (iter_step),
    .x       (iter_pos.x),
    .y       (iter_pos.y),
    .done    (iter_done)
);


logic kernel_step;
logic [1:0] kx, ky;
index_t kernel_pos, kernel_pos_w;
logic kernel_done;

assign {kernel_pos.x[$clog2(IMG_WIDTH)-1:2], kernel_pos.y[$clog2(IMG_WIDTH)-1:2]} = 0;
iterator #(
    .N       (3)
) u_iterator_kernel (
    .clk     (clk),
    .rst     (reset),
    .step    (kernel_step),
    .x       (kernel_pos.x[1:0]),
    .y       (kernel_pos.y[1:0]),
    .done    (kernel_done)
);

// assign kernel_pos = '{
// 	x:kx, y:ky
// };
logic pool_step;
index_t pool_pos;
logic pool_done;

assign pool_pos.x[COORD_WIDTH-1] = 0;
assign pool_pos.y[COORD_WIDTH-1] = 0;

iterator #(
    .N       (IMG_WIDTH/2)
) u_iterator_pool (
    .clk     (clk),
    .rst     (reset),
    .step    (pool_step),
	.x       (pool_pos.x[COORD_WIDTH-2:0]),
    .y       (pool_pos.y[COORD_WIDTH-2:0]),
    .done    (pool_done)
);

localparam bit signed [1:0] kernel_offset_x [3][3] = '{
	'{-2'sd1, 2'sd0, 2'sd1},
	'{-2'sd1, 2'sd0, 2'sd1},
	'{-2'sd1, 2'sd0, 2'sd1}
};

localparam bit signed [1:0] kernel_offset_y [3][3] = '{
	'{-2'sd1, -2'sd1, -2'sd1},
	'{ 2'sd0,  2'sd0,  2'sd0},
	'{ 2'sd1,  2'sd1,  2'sd1}
};

pixel_t max_value_r, max_value_w;

function pixel_t maximum;
	input pixel_t in1;
	input pixel_t in2;
	begin
		maximum = ($signed(in1) > $signed(in2)) ? in1 : in2;
	end
endfunction

function pixel_t round;
	input signed [ACC_WIDTH-1:0] round_input;
	begin
		round = $signed({round_input[FRAC_WIDTH*2+INT_WIDTH-1:FRAC_WIDTH]}) + round_input[FRAC_WIDTH-1];
	end
endfunction

function pixel_t zero_padding;
	input pixel_t zero_padding_input_from_ram;
	input index_t pos;
	input signed [1:0] offset_x;
	input signed [1:0] offset_y;
	begin
		if ((pos.x == 0 && offset_x == -2'sd1) ||
			(pos.x == IMG_WIDTH-1 && offset_x == 2'sd1) ||
			(pos.y == 0 && offset_y == -2'sd1) ||
			(pos.y == IMG_WIDTH-1 && offset_y == 2'sd1)
		) begin
			zero_padding = 0;
		end
		else begin
			zero_padding = zero_padding_input_from_ram;
		end
	end
endfunction

function [ACC_WIDTH-1:0] relu;
	input [ACC_WIDTH-1:0] relu_x;
	begin
		relu = ($signed(relu_x) < 0) ? 0 : relu_x;
	end
endfunction



assign busy = busy_r;
assign iaddr = input_pos_w;
assign cwr = cwr_w;
assign caddr_wr = caddr_wr_r;
assign cdata_wr = cdata_wr_w;
assign crd = crd_w;
assign caddr_rd = caddr_rd_w;
assign csel = csel_w;

// assign busy = busy_r;
// assign iaddr = iaddr_w;
// assign cwr = cwr_r;
// assign caddr_wr = caddr_wr_r;
// assign cdata_wr = cdata_wr_r;
// assign crd = crd_r;
// assign caddr_rd = caddr_rd_r;
// assign csel = csel_r;

logic signed [DATA_WIDTH-1:0] zero_padding_result;
assign zero_padding_result = zero_padding(.zero_padding_input_from_ram(idata),
	.pos(iter_pos),
	.offset_x(kernel_offset_x[kernel_pos.y][kernel_pos.x]),
	.offset_y(kernel_offset_y[kernel_pos.y][kernel_pos.x]));

logic signed [MUL_WIDTH-1:0] mul_result;
logic [1:0] pool_cnt_r, pool_cnt_w;
logic pool_offset_x, pool_offset_y;

// 4|16 , 4|16 ->  8|32
//               4|4|16|16

// 4+
assign mul_result = zero_padding_result * kernel[kernel_pos.y][kernel_pos.x];
assign acc_adder_result = $signed(acc_r) + $signed(mul_result);


always_comb begin : state_logic
	state_w = state_r;
	busy_w = 1;
	iter_step = '0;

	cwr_w = 0;
	crd_w = 0;
	caddr_wr_w = caddr_wr_r;
	caddr_rd_w = caddr_rd_r;
	csel_w = MEM_NONE;
	max_value_w = max_value_r;
	input_pos_w = input_pos_r;
	acc_w = acc_r;
	cdata_wr_w = cdata_wr_r;
	kernel_step = 0;
	pool_cnt_w = pool_cnt_r;
	pool_offset_x = 0;
	pool_offset_y = 0;
	pool_step = '0;

	unique case (state_r)
		S_IDLE: begin
			if (ready) begin
				state_w = S_CONV;
				busy_w = 1'b1;
				acc_w = 0;
			end
		end
		S_CONV: begin
			/*
				for x, y in input image
					result[x][y] = conv_inner(x, y)
			*/
			kernel_step = 0;
			state_w = S_CONV_INNER;

			// prefetch next pixel
			// kernel should stay at 0,0
			// write output to ram??

			acc_w = 0;
			// cdata_wr_w = acround(c_add)er_result;
			caddr_wr_w = iter_pos;
			// cdata_wr_w = relu(acc_r);
			cdata_wr_w = round(relu(acc_r + $signed({bias, {FRAC_WIDTH{1'b0}}})));
			cwr_w = 1;
			csel_w = MEM_LAYER0;

			// kernel_step = 1;
			// input_pos_w = { signed'(iter_pos.y) + kernel_offset_y[kernel_pos.x][kernel_pos.y],
			// 				signed'(iter_pos.x) + kernel_offset_x[kernel_pos.x][kernel_pos.y]};
		end
		S_CONV_INNER: begin
			/*
				for i, j in kernel
					acc += input[x+i][y+j] * kernel[i][j]
				kernel_pos : next kernel position fetch
			*/


			kernel_step = 1;

			// kernel_pos -> input_po

			input_pos_w = { ($clog2(IMG_WIDTH))'(signed'(iter_pos.y) + signed'(kernel_offset_y[kernel_pos.y][kernel_pos.x])),
							($clog2(IMG_WIDTH))'(signed'(iter_pos.x) + signed'(kernel_offset_x[kernel_pos.y][kernel_pos.x])) };
			acc_w = acc_adder_result;

			if (kernel_done) begin
				iter_step = 1;
				if(iter_done) begin
					state_w = S_BUBBLE;
				end else begin
					state_w = S_CONV;
				end
			end
		end
		S_BUBBLE: begin
			acc_w = 0;
			// cdata_wr_w = acround(c_add)er_result;
			caddr_wr_w = iter_pos;
			// cdata_wr_w = relu(acc_r);
			cdata_wr_w = round(relu(acc_r + $signed({bias, {FRAC_WIDTH{1'b0}}})));
			cwr_w = 1;
			csel_w = MEM_LAYER0;
			state_w = S_MAXPOOL;
			pool_cnt_w = 0;
			max_value_w = 20'h80000;
		end
		S_MAXPOOL: begin
			// pool_step = 1;
			// for x, y in (32, 32)
			//		do_maxpool(x*2, y*2)
			// pool_step = 1;
			// if (pool_done) begin
			// 	state_w = S_IDLE;
			// 	busy_w = 0;

			// end else begin
			// 	state_w = S_MAXPOOL_INNER;
			// 	pool_cnt_w = 0;
			// end

			state_w = S_MAXPOOL_INNER;
			caddr_wr_w = {pool_pos.y[$clog2(IMG_WIDTH)-2:0],
			pool_pos.x[$clog2(IMG_WIDTH)-2:0]};

			cdata_wr_w = max_value_r;
			max_value_w = 20'h80000;
			cwr_w = 1;
			csel_w = MEM_LAYER1;
		end
		S_MAXPOOL_INNER: begin
			case (pool_cnt_r)
				0: begin
					pool_offset_x = 0;
					pool_offset_y = 0;
				end
				1: begin
					pool_offset_x = 1;
					pool_offset_y = 0;
				end
				2: begin
					pool_offset_x = 0;
					pool_offset_y = 1;
				end
				3: begin
					pool_offset_x = 1;
					pool_offset_y = 1;
				end
			endcase
			crd_w = 1;
			csel_w = MEM_LAYER0;
			caddr_rd_w = { {pool_pos.y[$clog2(IMG_WIDTH)-2:0],pool_offset_y},
			{pool_pos.x[$clog2(IMG_WIDTH)-2:0],pool_offset_x}};

			pool_cnt_w = pool_cnt_r + 1;

			max_value_w = maximum(max_value_r, cdata_rd);

			if (pool_cnt_r == 3) begin
				pool_step = 1;
				if(pool_done) begin
					state_w = S_BUBBLE2;
				end else begin
					state_w = S_MAXPOOL;
				end
			end
		end
		S_BUBBLE2: begin
			caddr_wr_w = {pool_pos.y[$clog2(IMG_WIDTH)-2:0],
			pool_pos.x[$clog2(IMG_WIDTH)-2:0]};

			cdata_wr_w = max_value_r;
			max_value_w = 20'h80000;
			cwr_w = 1;
			csel_w = MEM_LAYER1;

			state_w = S_IDLE;
			busy_w = 0;
		end
		// default: begin
		// 	// state_w = S_CONV;
		// end
	endcase
end

// always_comb begin : sram_io
// 	iaddr_w = input_pos_w;

// 	cwr_w = cwr_r;
// 	crd_w = crd_r;
// 	caddr_wr_w = caddr_wr_r;
// 	caddr_rd_w = caddr_rd_r;
// 	csel_w = csel_r;

// 	if (state_r == S_INPUT) begin
// 		csel_w = MEM_NONE;

// 	end else begin

// 	end

// end

always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		state_r <= S_CONV;
		cnt_r <= 0;
		/* output registers */
		busy_r <= 1;
		iaddr_r <= 0;
		cwr_r <= 0;
		caddr_wr_r <= 0;
		cdata_wr_r <= 0;
		crd_r <= 0;
		caddr_rd_r <= 0;
		csel_r <= 0;

		input_pos_r <= 0;
		acc_r <= 0;
		pool_cnt_r <= 0;
		max_value_r <= 0;

	end else begin
		state_r <= state_w;
		cnt_r <= cnt_w;
		/* output registers */
		busy_r <= busy_w;
		iaddr_r <= iaddr_w;
		cwr_r <= cwr_w;
		caddr_wr_r <= caddr_wr_w;
		cdata_wr_r <= cdata_wr_w;
		crd_r <= crd_w;
		caddr_rd_r <= caddr_rd_w;
		csel_r <= csel_w;

		input_pos_r <= input_pos_w;
		acc_r <= acc_w;
		pool_cnt_r <= pool_cnt_w;
		max_value_r <= max_value_w;
	end
end
endmodule







































































module iterator #(parameter N = 16) (
	input clk,
	input rst,
	input step,
	output logic [$clog2(N)-1:0] x,
	output logic [$clog2(N)-1:0] y,
	output logic done
);

	assign done = (x == N-1) && (y == N-1);
	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			x <= 0;
			y <= 0;
		end else begin
			if (step) begin
				if (x == N-1) begin
					x <= 0;
					if (y == N-1) begin
						y <= 0;
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
