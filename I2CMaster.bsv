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
endinterface



typedef enum{
    Start,
    Write,
    Read,
    GetAck,
    PutAck,
    Stop
} Cmd deriving(Eq, FShow, Bits);


interface I2CMasterOperation;
    method Action put_cmd(Cmd cmd, Bit#(8) payload);
    method Bit#(8) get_result;    
    (*always_enabled,always_ready*)
    method Bool is_busy;
endinterface


interface I2CMaster;
    interface I2CMasterWires wires;
    interface I2CMasterOperation ops;
endinterface



module mkI2CMaster#(Integer log2_scl2clk_ratio)(I2CMaster);
    Reg#(Bit#(1)) scl_state <-mkReg(1);
    Reg#(Bit#(1)) sda_out_state <-mkReg(1);
    Reg#(Bit#(8)) out_buf <-mkReg('h55);
    Reg#(Bit#(8)) in_buf <-mkReg(0);
    Reg#(Bit#(1)) ack<-mkReg(0);
    Reg#(Bit#(1)) oe_state<-mkReg(1);
    Reg#(Bit#(1)) sda_in_state <- mkReg(1);
    Reg#(Bit#(1)) last_bit_in<-mkReg(1);
    Reg#(Cmd) last_cmd<-mkReg(?);

    
    

    function Stmt send_bit(Bit#(1) x);
        Stmt result=seq
            action
            sda_out_state<=x;
            oe_state<=1;
            endaction
            repeat(1<<(log2_scl2clk_ratio-2)) action
                scl_state<=0;
            endaction
            repeat(1<<(log2_scl2clk_ratio-1)) action
                scl_state<=1;
            endaction
            repeat(1<<(log2_scl2clk_ratio-2)) action
                scl_state<=0;
            endaction
        endseq;
        return result;
    endfunction

    Stmt recv_bit=seq
        oe_state<=0;
        repeat(1<<(log2_scl2clk_ratio-2)) action
            scl_state<=0;
        endaction
        repeat(1<<(log2_scl2clk_ratio-2)) action
            scl_state<=1;
        endaction
        last_bit_in <= sda_in_state;
        repeat(1<<(log2_scl2clk_ratio-2)) action
            scl_state<=1;
        endaction
        repeat(1<<(log2_scl2clk_ratio-2)) action
            scl_state<=0;
        endaction
    endseq;


    FSM send_fsm<-mkFSM(
        seq
            repeat(8)
            seq
                send_bit(out_buf[7]);
                out_buf<={out_buf[6:0], 1};
            endseq
        endseq
    );

    FSM read_fsm<-mkFSM(
        seq
            oe_state<=0;
            repeat(8)
            seq
                recv_bit;
                in_buf<={in_buf[6:0], last_bit_in};
            endseq
        endseq
    );

    FSM start_fsm<-mkFSM(
        seq
            repeat(1<<(log2_scl2clk_ratio-2)) action
                sda_out_state<=1;
                oe_state<=1;             
            endaction

            repeat(1<<(log2_scl2clk_ratio-2)) action
                scl_state<=1;                
            endaction
            repeat(1<<(log2_scl2clk_ratio-2)) action
                sda_out_state<=0;
            endaction
            repeat(1<<(log2_scl2clk_ratio-2)) action
                scl_state<=0;
            endaction
        endseq
    );

    FSM get_ack_fsm<-mkFSM(
        seq
            recv_bit;
            $display("ack=", last_bit_in);
            ack<=~last_bit_in;
        endseq
    );

    FSM put_ack_fsm<-mkFSM(
        seq
            send_bit(0);
        endseq
    );

    FSM stop_fsm<-mkFSM(
        seq
            repeat(1<<(log2_scl2clk_ratio-2)) action
                sda_out_state<=0;
                scl_state<=0;
                oe_state<=1;
            endaction
            repeat(1<<(log2_scl2clk_ratio-2)) action
                scl_state<=1;
            endaction
            repeat(1<<(log2_scl2clk_ratio-2)) action
            sda_out_state<=1;
            endaction
        endseq
    );

    

    Bool idle=send_fsm.done()&&read_fsm.done()&&start_fsm.done()&&get_ack_fsm.done()&&put_ack_fsm.done()&&stop_fsm.done();
    
    interface I2CMasterOperation ops;
        method Action put_cmd(Cmd cmd, Bit#(8) payload) if (idle);
            
            case (cmd) matches
                Start: start_fsm.start();
                Write: begin
                    last_cmd<= Write;
                    out_buf <= payload;
                    send_fsm.start();
                end
                Read: begin
                    last_cmd<=Read;
                    read_fsm.start();
                end
                GetAck: get_ack_fsm.start();
                PutAck: put_ack_fsm.start();
                Stop: stop_fsm.start();
            endcase
        endmethod

        method Bit#(8) get_result if(last_cmd==Write||last_cmd==Read);
            case (last_cmd) matches       
                Write: return extend(ack);
                Read: return in_buf;
                default: return 0;
            endcase
        endmethod
        method Bool is_busy=!idle;
    endinterface

    interface I2CMasterWires wires;
        method Bit#(1) scl_out=scl_state;
        method Bit#(1) sda_out=sda_out_state;
        method Bit#(1) oe_out=oe_state;
        method Action sda_in(Bit#(1) x);
            sda_in_state<=x;
        endmethod
        
    endinterface
    
endmodule





(* synthesize *)
module mkI2CMaster5(I2CMaster);
    I2CMaster i2cm<-mkI2CMaster(5);
    return i2cm;
endmodule

interface I2CScanner;
    interface I2CMasterWires wires;
    method Bit#(7) last_responsed;
endinterface

(*synthesize*)
module mkI2CScanner(I2CScanner);
    I2CMaster i2cm<-mkI2CMaster(10);
    Reg#(Bit#(7)) _last_responsed<-mkReg(0);
    Reg#(Bit#(7)) current_addr<-mkReg(0);
    mkAutoFSM(
        seq
            while(True)seq
                i2cm.ops.put_cmd(Start,0);
                i2cm.ops.put_cmd(Write,{current_addr,0});
                i2cm.ops.put_cmd(GetAck,0);
                i2cm.ops.put_cmd(Stop, 0);
                if(i2cm.ops.get_result!=0) _last_responsed<=current_addr;
                current_addr<=current_addr+1;
            endseq
        endseq
    );


    interface I2CMasterWires wires=i2cm.wires;
    method Bit#(7) last_responsed if(!i2cm.ops.is_busy);
        return _last_responsed;
    endmethod
endmodule

interface LM75Reader;
    interface I2CMasterWires wires;
    method Bit#(16) value;
    (*always_enabled,always_ready*)
    method Action slave_addr(Bit#(7) a);
endinterface


(*synthesize*)
module mkLM75Reader(LM75Reader);
    I2CMaster i2cm<-mkI2CMaster(7);
    Reg#(Bit#(16)) _value<-mkReg('haa);
    Reg#(Bit#(7)) addr<-mkReg(0);
    //Reg#(Bit#(8)) current_addr<-mkReg(0);
    mkAutoFSM(
        seq
            while(True)seq
                i2cm.ops.put_cmd(Start,0);
                i2cm.ops.put_cmd(Write,{addr,0});
                i2cm.ops.put_cmd(GetAck,0);

                
                i2cm.ops.put_cmd(Write,8'h00);
                i2cm.ops.put_cmd(GetAck,0);

                i2cm.ops.put_cmd(Start,0);
                i2cm.ops.put_cmd(Write,{addr,1});
                i2cm.ops.put_cmd(GetAck,0);
                
                //i2cm.ops.put_cmd(Stop, 0);
                i2cm.ops.put_cmd(Read,0);
                i2cm.ops.put_cmd(PutAck,0);
                action 
                    let x=i2cm.ops.get_result;
                    _value[15:8]<=x;
                endaction
                i2cm.ops.put_cmd(Read,0);
                i2cm.ops.put_cmd(PutAck,0);
                action 
                    let x=i2cm.ops.get_result;
                    _value[7:0]<=x;
                endaction
                i2cm.ops.put_cmd(Stop, 0);
            endseq
        endseq
    );


    interface I2CMasterWires wires=i2cm.wires;
    method Bit#(16) value() if(!i2cm.ops.is_busy);
        return _value;
    endmethod

    method Action slave_addr(Bit#(7) a);
        addr<=a;
    endmethod
endmodule
