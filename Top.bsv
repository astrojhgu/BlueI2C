import I2CMaster::*;
import I2CSlave::*;
import GetPut::*;
import ClientServer::*;
import StmtFSM::*;


module mkTop(Empty);
    I2CMaster i2cm<-mkI2CMaster(5);
    I2CSlave  i2cs<-mkI2CSlave(7'h32);
    Wire#(Bit#(1)) oe<- mkBypassWire;


    rule each1;
        let s=i2cm.wires.scl_out;
        i2cs.wires.scl_in(s);
    endrule

    rule each2;
        let s=i2cm.wires.sda_out;
        i2cs.wires.sda_in(s);
    endrule

    rule each3;
        oe<=i2cm.wires.oe_out;
    endrule

    rule each4;
        let s=i2cs.wires.sda_out();
        i2cm.wires.sda_in(s);
        //$display("a");
    endrule

    mkAutoFSM(
        seq
            $dumpon;
            
            i2cm.ops.request.put(tagged Start);
            i2cm.ops.request.put(tagged Write ({7'h33,0}));
            i2cm.ops.request.put(tagged GetAck);
            i2cm.ops.request.put(tagged Stop);
            i2cm.ops.request.put(tagged Start);
            i2cm.ops.request.put(tagged Write ({7'h32,0}));
            i2cm.ops.request.put(tagged GetAck);
            i2cm.ops.request.put(tagged Stop);

            i2cm.ops.request.put(tagged Start);
            i2cm.ops.request.put(tagged Write ({7'h33,0}));
            i2cm.ops.request.put(tagged GetAck);
            i2cm.ops.request.put(tagged Stop);

            i2cm.ops.request.put(tagged Start);
            i2cm.ops.request.put(tagged Write ({7'h32,0}));
            i2cm.ops.request.put(tagged GetAck);
            i2cm.ops.request.put(tagged Stop);
            //repeat(500) noAction;
            //i2cm.ops.start(False);
            //while(i2cm.wires.is_busy) noAction;
            //noAction;
        endseq
    );



endmodule

//module lm75Reader(I2C

module mkTop1(Empty);
    I2CScanner i2cscanner<-mkI2CScanner;
    I2CSlave  i2cs<-mkI2CSlave(7'h32);
    Wire#(Bit#(1)) oe<- mkBypassWire;


    rule each1;
        let s=i2cscanner.wires.scl_out;
        i2cs.wires.scl_in(s);
    endrule

    rule each2;
        let s=i2cscanner.wires.sda_out;
        i2cs.wires.sda_in(s);
    endrule

    rule each3;
        oe<=i2cscanner.wires.oe_out;
    endrule

    rule each4;
        let s=i2cs.wires.sda_out();
        i2cscanner.wires.sda_in(s);
        //$display("a");
    endrule


    mkAutoFSM(
        seq
            repeat(1000) $display(i2cscanner.last_responsed);
        endseq
    );


endmodule

//module lm75Reader(I2C