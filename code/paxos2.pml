#define ACCEPTORS 5
#define PROPOSERS 2
#define MAJ ((ACCEPTORS/2)+1) // majority
#define MAX (ACCEPTORS*PROPOSERS)
typedef mex{
	byte rnd;
	short prnd;
	short pval;
}

chan prepare =  [MAX] of { byte,  byte };
chan accept  =  [MAX] of { byte,  byte, short };
chan promise = [MAX]  of { mex };
chan learn   =    [MAX]  of { short, short, short };

inline baccept(round,v){
    for(i:1.. ACCEPTORS){
       accept!!i,round,v;
    }
    i=0;
}

inline bprepare(round){
    for(i:1.. ACCEPTORS){
      prepare!!i,round;
    }
    i=0;
}

proctype proposer(short crnd; short myval) {
    short aux, hr = -1, hv = -1;
    short rnd;
    short prnd,pval;
    byte count=0,i=0;
    mex pr;
    d_step{
      bprepare(crnd);
    }
end:  
    do
    :: 
    atomic{
    d_step{
     i=0;
     count=0;
         do
             :: i < len(promise) ->
		  promise?pr; promise!pr;		/* rotate in place */
            if  
              ::pr.rnd==crnd->
                 count++;
         if
          ::pr.prnd>hr->
                 hr=pr.prnd;
                 hv=pr.pval;
          ::else->skip;
         fi;
         ::else->skip;
        fi;  /* from the user code in the for body */
		    i++;
	   :: else -> 
		     pr.prnd=0;
		     pr.pval=0;
		     pr.rnd=0;
		     i=0;
		     break;
	  od;
    } 
    if ::count>=MAJ ->
	    d_step{ 
            	aux=(hr<0->myval : hv);
            	baccept(crnd,aux);
            }
            break;
       ::else fi;
	 d_step{ hv= -1; hr = -1; count =0;aux=0; } /* reset */
      }
    od
}



proctype acceptor(int id) {
   short crnd = -1, prnd = -1, pval = -1;
   short aval,rnd;

end:
   do
    ::  d_step { 
          prepare??eval(id),rnd ->
          if :: (rnd>crnd)  ->
                 crnd=rnd;
	 promise!!crnd,prnd,pval;
             :: else fi; 
          rnd = 0 /* reset */
        }
     :: d_step { 
          accept??eval(id),rnd,aval ->
          if :: (rnd>=crnd) ->
                  crnd=rnd; 
                  prnd=rnd;
                  pval=aval;
                  learn!!id,crnd,aval;
              :: else 
          fi; 
          rnd = 0; aval = 0 /* reset */
        }
    od
}

active proctype learner() {
    short lastval = -1, id, rnd, lval;
    byte mcount[PROPOSERS];

end:
    do :: d_step {
           learn??id,rnd,lval ->
              if :: mcount[rnd-1] < MAJ -> mcount[rnd-1]++;
	             :: else fi;
              if ::mcount[rnd-1] >= MAJ   ->
                    if :: (lastval >= 0 && lastval != lval) -> assert(false);
                       :: (lastval == -1) -> lastval = lval;
                       :: else  fi
                 :: else fi; 
           id = 0; rnd = 0; lval = 0 /* reset */
     }
    od
}




init
{
 atomic {
   byte i;
   for(i:1.. PROPOSERS){
   	run proposer(i,i);
   }
   for(i:1.. ACCEPTORS){
   	run acceptor(i);
   }
  }