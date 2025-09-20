interface I2CSlaveWires;
(*always_enabled,always_ready*)
    method Action scl_in(Bit#(1) x);
(*always_enabled,always_ready*)
    method Bit#(1) sda_out;
(*always_enabled,always_ready*)
    method Action sda_in(Bit#(1) x);
(*always_enabled,always_ready*)
    method Bool is_busy;
endinterface



interface I2CSlaveOperation;
    
endinterface

interface I2CSlave;
    interface I2CSlaveWires wires;
    interface I2CSlaveOperation ops;
endinterface


typedef enum {
    SIdle//0x000
    ,SStarted//0x001
    ,SRecevingAddr//0x010
    ,SSendingAddrAck//0x011
    ,SWaitingMrSwAck//0x100
    ,MrSw//0x101
    ,MwSr//0x110
    ,SSendingMwSrAck//0x111
}SlaveState deriving(Eq, FShow, Bits);


module mkI2CSlave#(Bit#(7) addr)(I2CSlave);
    Reg#(Bit#(1)) scl_state <-mkReg(1);
    Reg#(Bit#(1)) scl_state_old <- mkReg(1);

    Reg#(Bit#(1)) sda_in_state <- mkReg(1);
    Reg#(Bit#(1)) sda_out_state <-mkReg(1);
    Reg#(Bit#(1)) sda_in_state_old <- mkReg(1);
    Reg#(Bit#(8)) out_buf <-mkReg('haa);
    Reg#(Bit#(8)) in_buf <-mkReg(0);
    Reg#(Bit#(1)) ack<-mkReg(0);
    
    Reg#(Bit#(1)) last_sda <- mkReg(1);
    Reg#(Bit#(1)) last_bit_in<-mkReg(1);
    
    Reg#(UInt#(4)) bit_cnt<-mkReg(0);

    Reg#(Bit#(8)) addr_received <- mkReg(0);

    Reg#(SlaveState) state <-mkReg(SIdle);
    rule inputs;
        sda_in_state_old <= sda_in_state;
        scl_state_old <= scl_state;
    endrule
    

    Bit#(2) sda_in_states={sda_in_state_old, sda_in_state};
    Bit#(2) scl_states={scl_state_old, scl_state};
    rule start(scl_state==1 && sda_in_states==2'b10);
        sda_out_state<=1;
        state<=SStarted;
    endrule

    rule r_idle(scl_state==1 && sda_in_states==2'b01);
        state<=SIdle;
    endrule

    

    rule r_starting(state==SStarted && scl_states==2'b10);
        state<=SRecevingAddr;
        bit_cnt<=0;
    endrule

    rule r_receving_addr (state==SRecevingAddr && scl_states==2'b01 && bit_cnt!=8);
        addr_received <= {addr_received[6:0], sda_in_state};
        bit_cnt<=bit_cnt+1;
        if (bit_cnt==7) state<=SSendingAddrAck;
    endrule

    rule r_sending_ack1 (state==SSendingAddrAck && scl_states==2'b10);
        $display("a");    
        if (addr_received[7:1]==addr)begin
            $display("addr received= ", addr_received," addr=",  addr, " RW:", (addr_received[0]==1));
            
            if(sda_out_state==1) sda_out_state<=0;
            else begin
                sda_out_state<=1;
                state <= addr_received[0]==1?MrSw:MwSr;
            end
        end
        else begin
            state <= SIdle;
            sda_out_state<=1;
        end
        bit_cnt<=0;
        //sda_out_state<=(addr_received[7:1]==addr?0:1;
    endrule

    

    rule mrsw (state==MrSw && scl_states==2'b10);
        $display(sda_out_state);
        sda_out_state<=out_buf[7];
        out_buf<={out_buf[6:0], 1};
        bit_cnt<=bit_cnt+1;
        if (bit_cnt==7)begin
            state<=SWaitingMrSwAck;
        end
    endrule

    rule mrsw_ack(state==SWaitingMrSwAck);
        if(scl_states==2'b01)
            ack<=sda_in_state;
        else if (scl_states==2'b10)
            state<=MrSw;        
    endrule

    rule mwsr1 (state==MwSr && scl_states==2'b10);
        sda_out_state<=1;
    endrule

    rule mwsr2 (state==MwSr && scl_states==2'b01);
        in_buf<={in_buf[6:0], sda_in_state};
        bit_cnt<=bit_cnt+1;
        if(bit_cnt==7) begin
            state<=SSendingAddrAck;
        end
        $display("a", bit_cnt, " ",state);
    endrule



    

    

    interface I2CSlaveWires wires;
        method Action scl_in(Bit#(1) x);
            scl_state <=x;
        endmethod
        
        method Bit#(1) sda_out;
            return sda_out_state;
        endmethod

        method Action sda_in(Bit#(1) x);
            sda_in_state<=x;
        endmethod

        method Bool is_busy=state==SIdle;
endinterface


    
endmodule
