// 仅在测试全部断言结束后写结构化结果；vsim退出码及PASS字符串不作独立判据。
task automatic complete_test(input [511:0] name,input integer checks);
    reg [2047:0] result_path;integer handle,found;
    begin
        found=$value$plusargs("RESULT=%s",result_path);
        if(!found||checks<=0)$fatal(1,"missing result path/check count");
        handle=$fopen(result_path,"w");
        if(!handle)$fatal(1,"cannot write result");
        $fwrite(handle,"STATUS=PASS\nTEST=%0s\nCHECKS=%0d\n",name,checks);
        $fclose(handle);
    end
endtask
