SECTIONS
{
    . = 0x00000000;
    .data :{
        * (.data1);
        * (.data2);
        * (.data3);
        * (.data4);
        * (.data5);
    }
    .text : {
        * (.start);
        * (.text);
    }

}
