import uvm_pkg::*;
`include "uvm_macros.svh"
`timescale 1ns/1ps


interface my_intf(input logic Clk,reset);
    logic [3:0] a;
  logic [3:0] b;
  logic       c;
  logic [3:0] out;
  logic [1:0] op;
endinterface


class transaction extends uvm_sequence_item;

    rand bit [3:0] a;
  rand bit [3:0] b;
  rand bit [1:0] op;
       bit [6:0] c;
       bit [6:0] out;

    function new(input string inst = "transaction");
        super.new(inst);
    endfunction

    `uvm_object_utils_begin(transaction)
    `uvm_field_int(a,UVM_DEC)
    `uvm_field_int(b,UVM_DEC)
    `uvm_field_int(op,UVM_DEC)
    `uvm_field_int(c,UVM_DEC)
    `uvm_field_int(out,UVM_DEC)
    `uvm_object_utils_end
endclass //transaction extends uvm_sequence_item


class generator extends uvm_sequence #(transaction);
    `uvm_object_utils(generator)

    transaction trans;

    //coverage:
    covergroup cg;
        cp1:coverpoint trans.a;
        cp2:coverpoint trans.b;
        cp3:coverpoint trans.op;
        cp4:cross trans.a,trans.b,trans.op;

    endgroup

    function new(input string inst = "generator");
        super.new(inst);
        cg = new();
    endfunction

    virtual task body();
    trans = transaction::type_id::create("trans");
    for (int i = 0;i<8000 ; i++) begin
        start_item(trans);
        assert(trans.randomize());
        cg.sample();
        finish_item(trans);
        
    end
    #10;
    endtask
endclass //generator extends uvm_sequence


class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver)

    transaction trans;
    virtual my_intf drv_intf;

    function new(input string inst ="driver",uvm_component comp);
        super.new(inst, comp);
    endfunction //new()

    virtual function void build_phase( uvm_phase phase);
        super.build_phase(phase);
        trans = transaction::type_id::create("trans");
        
        if(!uvm_config_db#(virtual my_intf)::get(this,"","my_intf", drv_intf))
            `uvm_fatal("driver", "Unable to access interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(trans);
            trans.print();
            drv_intf.a = trans.a;
            drv_intf.b = trans.b;
            drv_intf.op = trans.op;
            seq_item_port.item_done();
            @(negedge drv_intf.Clk);
        end
    endtask
endclass //driver extends uvm_driver


class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    transaction trans;
    virtual my_intf mon_intf;
    uvm_analysis_port #(transaction) mon_ap;

    function new(input string inst ="driver",uvm_component comp);
        super.new(inst, comp);
        mon_ap = new("mon_ap", this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        trans = transaction::type_id::create("trans");
        
        if(!uvm_config_db#(virtual my_intf)::get(this,"","my_intf", mon_intf))
            `uvm_fatal("monitor", "Unable to access interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            @(posedge mon_intf.Clk);
            trans.a = mon_intf.a;
            trans.b = mon_intf.b;
            trans.op = mon_intf.op;
            //#1
            @(negedge mon_intf.Clk);
            trans.out = mon_intf.out;
            trans.c = mon_intf.c;
            //trans.print();
            mon_ap.write(trans);
        end
    endtask
endclass //monitor extends uvm_monitor


class agent extends uvm_agent;
    `uvm_component_utils(agent)

    uvm_analysis_port #(transaction) agt_ap;

    transaction trans;

    driver drv;
    monitor mon;
    uvm_sequencer #(transaction) seqr;

    function new(input string inst ="agent",uvm_component comp);
        super.new(inst, comp);
        agt_ap = new("agt_ap", this);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = driver::type_id::create("drv1",this);
        mon = monitor::type_id::create("mon1",this);
        seqr = uvm_sequencer #(transaction)::type_id::create("seqr", this);
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.mon_ap.connect(agt_ap);
    endfunction
endclass


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp #(transaction, scoreboard) sco_ap;

    transaction trans[$];

    function new(input string inst ="scoreboard",uvm_component comp);
        super.new(inst, comp);
        sco_ap = new("sco_ap", this);
    endfunction //new()

    virtual function void write(transaction recv);
        trans.push_back(recv);
        `uvm_info(get_type_name, "inside write function",UVM_NONE)
    endfunction

    virtual task run_phase(uvm_phase phase);
        //trans.print(uvm_default_line_printer);
        transaction trans_item;
        int prev_counter = 0;
        int error;//count no. of transactions gives error
        int pass;//count no. of transactions passes
        forever begin
            //`uvm_info(get_type_name,"inside scoreboard",UVM_NONE)
            wait(trans.size>0);
            
            if(trans.size>0)begin
                trans_item = trans.pop_front();
                //$display(get_type_name, "doneee");
                case (trans_item.op)
            0: begin
                if((trans_item.a+trans_item.b) == {trans_item.c,trans_item.out})begin
                    $display("Result is as Expected");
                    pass++;
                end
                else begin
                    $error("Wrong Result.\n\tExpeced: %0d Actual: %0d",(trans_item.a+trans_item.b),{trans_item.c,trans_item.out});
                    error++;
                end
            end
            1: begin
                if((trans_item.a ^ trans_item.b) == {trans_item.c,trans_item.out})begin
                    $display("Result is as Expected");
                    pass++;
                end
                else begin
                    $error("Wrong Result.\n\tExpeced: %0d Actual: %0d",(trans_item.a ^ trans_item.b),{trans_item.c,trans_item.out});
                    error++;
                end
            end
            2: begin
                if((trans_item.a & trans_item.b) == {trans_item.c,trans_item.out})begin
                    $display("Result is as Expected");
                    pass++;
                end
                else begin
                    $error("Wrong Result.\n\tExpeced: %0d Actual: %0d",(trans_item.a & trans_item.b),{trans_item.c,trans_item.out});
                    error++;
                end
            end
            3: begin
                if((trans_item.a | trans_item.b) == {trans_item.c,trans_item.out})begin
                    $display("Result is as Expected");
                    pass++;
                end
                else begin
                    $error("Wrong Result.\n\tExpeced: %0d Actual: %0d",(trans_item.a | trans_item.b),{trans_item.c,trans_item.out});
                    error++;
                end
            end
            default: $error("wrong operand");
        endcase
        $display("error: %0d, pass: %0d",error,pass);
        end
        end
    endtask
endclass //scoreboard extends uvm_scoreboard


class environment extends uvm_env;
    `uvm_component_utils(environment)

    agent agt;
    scoreboard sco;

    function new(input string inst ="environment",uvm_component comp);
        super.new(inst, comp);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = agent::type_id::create("agt1", this);
        sco = scoreboard::type_id::create("sco1", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        agt.agt_ap.connect(sco.sco_ap);
    endfunction
endclass //environment extends uvm_env


class test1 extends uvm_test;
    `uvm_component_utils(test1)

    generator gen;
    environment env;

    function new(input string inst ="test1",uvm_component comp);
        super.new(inst, comp);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    gen = generator::type_id::create("gen1", this);
    env = environment::type_id::create("env1", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        gen.start(env.agt.seqr);
        #10000;
        `uvm_info("test1","before dropping objection",UVM_NONE)
        `uvm_info("test1",$sformatf("coverage is %.2f%%",gen.cg.get_inst_coverage()),UVM_NONE);
        phase.drop_objection(this);
    endtask
endclass //test1 extends uvm_test


module uvm_tb ();
    test1 t1;
    //clock and reset signal declaration
    bit clk;
    bit reset;

    //clock generation
    always #5 clk = ~clk;
    
    //reset Generation
    initial begin
        reset = 1;
        #5 reset =0;
    end

    my_intf my_intf_instance(clk, reset);

    ALU DUT (

        .a(my_intf_instance.a),
        .b(my_intf_instance.b),
        .op(my_intf_instance.op),
        .c(my_intf_instance.c),
        .out(my_intf_instance.out)
    );
    

    initial begin
        $dumpvars;
        t1 = new("t1", null);
        uvm_config_db #(virtual my_intf)::set(null, "*", "my_intf", my_intf_instance);
        run_test();
        //#500;
    end
endmodule