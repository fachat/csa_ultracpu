
1 rem up,up, and away
5 print "{CLR}"
10 v=59520:rem start of display chip
11 poke v,59:poke v+1,1+2+4:rem enable sprite 2, x-expand, y-expand
12 poke 32768+2048-8+2,80:rem sprite 2 data from block 80
13 poke v,82:poke v+1,5:rem set sprite foreground color
20 for n=0 to 62: read q:poke 32768+1024+n,q:next
30 for x=0 to 200
40 poke v,56:poke v+1,x:rem update x coordinates
50 poke v,57:poke v+1,x:rem update y coordinates
60 next x
70 goto 30
200 data 0,127,0,1,255,192,3,255,224,3,231,224
210 data 7,217,240,7,223,240,7,217,240,3,231,224
220 data 3,255,224,3,255,224,2,255,160,1,127,64
230 data 1,62,64,0,156,128,0,156,128,0,73,0,0,73,0
240 data 0,62,0,0,62,0,0,62,0,0,28,0

