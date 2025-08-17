module async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8  
)(
    input  wire                  wclk,
    input  wire                  rclk,
    input  wire                  rst_n,
    input  wire                  wr_en,
    input  wire                  rd_en,
    input  wire [DATA_WIDTH-1:0] wdata,
    output wire [DATA_WIDTH-1:0] rdata,
    output wire                  wfull,
    output wire                  rempty
);

    // Write and read pointers
    reg [ADDR_WIDTH-1:0] wr_ptr_bin = 0, wr_ptr_gray = 0;
    reg [ADDR_WIDTH-1:0] rd_ptr_bin = 0, rd_ptr_gray = 0;

    // Synchronizers for crossing domains
    reg [ADDR_WIDTH-1:0] wr_ptr_gray_rdclk1 = 0, wr_ptr_gray_rdclk2 = 0;
    reg [ADDR_WIDTH-1:0] rd_ptr_gray_wrclk1 = 0, rd_ptr_gray_wrclk2 = 0;

    // Memory
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // Convert binary to Gray code
    function [ADDR_WIDTH-1:0] bin2gray(input [ADDR_WIDTH-1:0] bin);
        bin2gray = bin ^ (bin >> 1);
    endfunction

    // Convert Gray code to binary
    function [ADDR_WIDTH-1:0] gray2bin(input [ADDR_WIDTH-1:0] gray);
        integer i;
        begin
            gray2bin[ADDR_WIDTH-1] = gray[ADDR_WIDTH-1];
            for (i = ADDR_WIDTH-2; i >= 0; i=i-1)
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
        end
    endfunction

    // Write pointer logic
    always @(posedge wclk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr_bin <= 0;
        else if (wr_en && !wfull)
            wr_ptr_bin <= wr_ptr_bin + 1;
    end

    always @(posedge wclk) begin
        wr_ptr_gray <= bin2gray(wr_ptr_bin);
    end

    // Read pointer logic
    always @(posedge rclk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr_bin <= 0;
        else if (rd_en && !rempty)
            rd_ptr_bin <= rd_ptr_bin + 1;
    end

    always @(posedge rclk) begin
        rd_ptr_gray <= bin2gray(rd_ptr_bin);
    end

    // Synchronize write pointer into read clock domain
    always @(posedge rclk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr_gray_rdclk1 <= 0;
            wr_ptr_gray_rdclk2 <= 0;
        end else begin
            wr_ptr_gray_rdclk1 <= wr_ptr_gray;
            wr_ptr_gray_rdclk2 <= wr_ptr_gray_rdclk1;
        end
    end

    // Synchronize read pointer into write clock domain
    always @(posedge wclk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr_gray_wrclk1 <= 0;
            rd_ptr_gray_wrclk2 <= 0;
        end else begin
            rd_ptr_gray_wrclk1 <= rd_ptr_gray;
            rd_ptr_gray_wrclk2 <= rd_ptr_gray_wrclk1;
        end
    end

    // wfull and rempty flags
    assign wfull  = (bin2gray(wr_ptr_bin + 1) == {~rd_ptr_gray_wrclk2[ADDR_WIDTH-1:ADDR_WIDTH-2], rd_ptr_gray_wrclk2[ADDR_WIDTH-3:0]});
    assign rempty = (rd_ptr_gray == wr_ptr_gray_rdclk2);

    // Memory write
    always @(posedge wclk) begin
        if (wr_en && !wfull)
            mem[wr_ptr_bin] <= wdata;
    end

    // Memory read
    assign rdata = mem[rd_ptr_bin];

endmodule
