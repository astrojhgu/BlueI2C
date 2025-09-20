import StmtFSM::*;
interface I2CMasterWires;
(*always_enabled,always_ready*)
    method Bit#(1) scl_out;
(*always_enabled,always_ready*)
    method Bit#(1) sda_out;
(*always_enabled,always_ready*)
    method Action sda_in(Bit#(1) x);
(*always_enabled,always_ready*)
    method Bit#(1) oe_out;
(*always_enabled,always_ready*)
    method Bool is_busy;
endinterface





interface I2CMasterOperation;
    method Action write(Bit#(8) d, Bool repeating);
    method Action stop;
    method Action send_data_raw(Bit#(8) x);
    method Action read_bit();
endinterface


interface I2CMaster;
    interface I2CMasterWires wires;
    interface I2CMasterOperation ops;
endinterface


(*synthesize*)
module mkI2CMaster(I2CMaster);
    Reg#(Bit#(1)) scl_state <-mkDWire(1);
    Reg#(Bit#(1)) sda_out_state <-mkDWire(1);
    Reg#(Bit#(8)) out_buf <-mkReg('h55);
    Reg#(Bit#(8)) in_buf <-mkReg(0);
    Reg#(Bit#(1)) ack<-mkReg(0);
    Reg#(Bit#(1)) oe_state<-mkDWire(1);
    Reg#(Bit#(1)) sda_in_state <- mkBypassWire;
    Reg#(Bit#(1)) last_sda <- mkReg(1);

    Stmt send_bits=seq
            action
                scl_state<=0;
                sda_out_state<=out_buf[7];                
            endaction
            action
                scl_state<=1;
                sda_out_state<=out_buf[7];
            endaction
            action
                scl_state<=1;
                sda_out_state<=out_buf[7];
            endaction
            action
                scl_state<=0;
                sda_out_state<=out_buf[7];
                out_buf<={out_buf[6:0], 1};
            endaction
        endseq;

    FSM write_fsm<-mkFSM(seq
        action
                scl_state<=1;
                sda_out_state<=1;
                //oe_state<=0;
        endaction
        action
            scl_state<=1;
            sda_out_state<=0;
        endaction
        action
            scl_state<=0;
            sda_out_state<=0;
        endaction

        repeat(8)send_bits;
            action
                scl_state<=0;
                sda_out_state<=1;
                oe_state<=0;
            endaction
            action
                scl_state<=1;
                sda_out_state<=1;
                oe_state<=0;
                ack<=sda_in_state;
            endaction
            action
                scl_state<=1;
                sda_out_state<=1;
                oe_state<=0;
                
            endaction

            action
                scl_state<=0;
                sda_out_state<=1;
                oe_state<=0;
            endaction

            
            
    endseq);

    FSM stop_fsm<-mkFSM(
        seq
            action
            scl_state<=1;
            sda_out_state<=0;
            endaction
            
            action
            scl_state<=1;
            sda_out_state<=1;
            endaction
        endseq
    );
    

    Bool idle=write_fsm.done()&&stop_fsm.done();


    
    interface I2CMasterOperation ops;
        method Action write(Bit#(8) d, Bool repeating) if(idle);
            ack<=0;
            //sda_out_state<=1;
            out_buf<=d;
            scl_state<=repeating?0:1;
            //last_sda<=l;
            write_fsm.start();
        endmethod


        method Action stop() if(idle);
            sda_out_state<=0;
            scl_state<=0;
            stop_fsm.start();
        endmethod
    endinterface

    interface I2CMasterWires wires;
        method Bit#(1) scl_out=scl_state;
        method Bit#(1) sda_out=sda_out_state;
        method Bit#(1) oe_out=oe_state;
        method Action sda_in(Bit#(1) x);
            sda_in_state<=x;
        endmethod
        method Bool is_busy=!idle;
    endinterface
    
endmodule

