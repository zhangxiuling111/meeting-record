#define ACCEPTORS 4
#define PROPOSERS 3
#define COORDINATORS 3
#define QUORUM 3

byte proposal[PROPOSERS];
byte pcount = 0;
byte leaderno = 0
bool leaderselected = false;
bool progress = false;
bool proposed = false;


chan coorproposal[COORDINATORS] = [10] of {byte,byte}        /*所有的proposer都先将proposal发送到该通道给coordinator*/
chan prereply[COORDINATORS] = [10] of {byte};                 /*当acceptor的当前round大于coordinator的当前的round值时，acceptor提醒coordinator更大的round值*/
chan accreply[COORDINATORS] = [10] of {byte};
chan acceptorpre[ACCEPTORS] = [10] of {byte,byte};     /*acceptor用来接收prepare信息*/
chan acceptoracc[ACCEPTORS] = [10] of {byte,byte, short};     /*acceptor用来接收accept请求*/
chan promise[COORDINATORS] = [10] of {byte, byte,byte,byte} ;           /*coordinator向acceptor加入round的请求后用来接收promise信息*/
chan learnacc = [10] of {byte,byte,byte};                     /*acceptor接受一个value后发送到该通道用来提醒learner*/
chan learned = [10] of {byte,byte};                          /*learner对同一个value计数超过majority，表示learn到一个value之后则向通道发送被接收的value*/
chan coordinatoracc[COORDINATORS] = [10] of {byte, byte, byte}  //每当acceptor接收了一个value，在通知learner的同时也会将消息发送给coordinator，coordinator可以以此来判断是否会发生冲突。 


ltl {<>(progress==1)};


inline cooraccept(id, round, value){
	byte i;
	for(i : 0 .. (ACCEPTORS-1)){
		acceptoracc[i]!id,round,value;                //由coordinator向所有的acceptor发送accept请求
	}
	i = 0;
}

inline lprepare(id, round){
	byte i;
	for(i : 0 .. (ACCEPTORS-1)){
		acceptorpre[i] ! id,round;                    //由coordinator向所有的acceptor发送prepare请求
	}
	i = 0;
}

inline anymessage(id, round){
	byte i;
	for(i : 0 .. (ACCEPTORS-1)){
		acceptoracc[i]!id,round,-1;                //由coordinator向所有的acceptor发送anymessage
	}
	i = 0;
}

inline proaccept(id, round, value){
	byte i;
	for(i : 0 .. (ACCEPTORS-1)){
		acceptoracc[i]!id,round,value;                //由proposer直接向所有的acceptor发送accept请求
	}
	i = 0;
}


proctype leader(){                                   //leader election
	select(leaderno : 0 .. (COORDINATORS-1));
	leaderselected = true;                            //确保选出了leader之后再执行coordinator
}


proctype coordinator(byte id){
	byte crnd = 0,cval = 0;
	byte prornd,proval,accrnd ;                       //promise返回的已接收的最高的round，value和acceptor当前的round；
	byte replyrnd;  
	byte val=0;                     				 //proposer 提出的value
	byte accid,proid;               				 //分别为acceptor和proposer的ID
	byte precount = 0;
	byte pre[ACCEPTORS];
	byte k;
	byte accval;                      //acceptor接受的value
	byte acccount[PROPOSERS];           //用来保存每个value的接收次数,最多有proposers个value
	byte accvalue[ACCEPTORS];   //用来判断是否已经接收过来自某个acceptor的信息,若同一个idde acceptor接受多次，则不用反复计数
	byte acceptorscount = 0, accmax = 0;//分别表示已经接收了value的acceptor的个数和被接受次数最多的value的次数，用来判断是否会发生冲突，因为如果所有的acceptor都已经接收了value，却没有任何一个value的接受次数达到quorum，则有冲突
	byte maxvalue; //用来记录被接受次数最多的value值，即accmax对应的value
	do
	:: (precount < QUORUM && !progress) ->
	    if 
	    ::  atomic{promise[id] ? [accid,accrnd,prornd,proval] -> promise[id] ? accid,accrnd,prornd,proval}       //查看acceptor返回的promise信息
	        if
	        :: accrnd !=0 && accrnd == crnd -> 
		        if
		        :: pre[accid] ==0 ->
		                      d_step{
		                      	if
		                      	:: proval > cval -> cval = proval;
		                      	::else -> skip;
		                      	fi
		                      	pre[accid]=1;
		                      	precount ++;

		                      }
		        :: pre[accid] == 1 -> skip
		        fi
		    fi
		:: atomic {prereply[id] ? [replyrnd]  -> prereply[id] ? replyrnd}    //查看acceptor发送通知信息，即更大的round number,回到初始状态，并清零所有计数
		    if 
		    ::  replyrnd >crnd -> atomic{
		   	  crnd = replyrnd+1;
		   	  for(k : 0 .. ACCEPTORS-1){
		    		pre[k] = 0
		    	}
		    	k =0;
		   	  precount = 0
		   	  lprepare(id,crnd);
		      }
		  
		    fi
		:: crnd == 0 -> atomic{
		  	 crnd++;
		  	 lprepare(id,crnd)
		  }
		:: else ->skip;
	    fi


	 
	:: precount >= QUORUM ->
        if
        ::atomic{accreply[id] ? [replyrnd] -> accreply[id] ? replyrnd}
	        if 
	        ::replyrnd > crnd -> atomic{
	   	      crnd = replyrnd + 1;
	   	      precount = 0;
	   	      for(k : 0 .. ACCEPTORS-1){
		    	    pre[k] = 0
		    	    }
		    	    k = 0;
             lprepare(id,crnd);

 	        } 
 	        fi
	    ::(cval == 0) -> atomic{               //当所有的promise中都没有value值，则coordinator向acceptor发送any message；
	  	  
     	       anymessage(id,crnd);
     	       byte j = 0;
     	       for(j : 0..(PROPOSERS-1)){       //发送any message之后，则proposer向acceptor直接发送proposal
		   	   	    proaccept(j, crnd, j+1);
		   	    }
		   	    j = 0;
     	    }
        :: cval != 0 && !progress ->atomic{
        	cooraccept(id,crnd,cval)             //若promise中包含value值，则和classic paxos一样，coordinator向acceptor发送正常accept请求；
        } 


        :: progress == true -> break;
        fi

    :: precount >= QUORUM && accmax < QUORUM && acceptorscount < QUORUM ->           //对acceptor接受的value及各value的接收次数进行计数
    	if 
	    ::  atomic{coordinatoracc[id] ? [accid,accrnd,accval] -> coordinatoracc[id] ? accid,accrnd,accval}  
	    	if
	    	:: accrnd !=0 && accrnd == crnd ->
	    		if
	    		:: accvalue[accid] == 0 ->
	    			d_step{
	    				cval = 10;               //表示已经进入phase2b阶段，不用再发送anymessage
	    				acccount[accval-1] ++;
	    				accvalue[accid] = 1;
	    				acceptorscount ++;
	    				if 
	    				:: acccount[accval-1] > accmax ->atomic{
	    					accmax = acccount[accval-1];
	    				    maxvalue = accval;
	    				}
	    				    
	    				:: else -> skip;
	    				fi
	    			}
	    		:: accvalue[accid] == 1 -> skip;
	    		fi
	    	fi
	    fi
	:: precount >= QUORUM && accmax >= QUORUM /*&& acceptorscount < QUORUM */->       //acceptor对某个value的接受次数达到quorum
		atomic{
			learned ! crnd,accval;
		}

	:: precount >= QUORUM && accmax < QUORUM && acceptorscount >= QUORUM ->        //quorum中所有的acceptor都已经接收了value，却没有任何一个value的接受次数达到quorum，则有冲突
		//发生冲突，使用coordinated recovery,直接开始crnd+1 的phase 2a阶段，由coordinator直接向acceptor直接发送accept请求
		atomic{
			crnd ++;
			do
			:: select(cval : 1 .. PROPOSERS);
			:: acccount[cval-1] != 0 -> break;   //若等于0，则代表该proposer没有向acceptor发送proposal；
			od

     	    cooraccept(id,crnd,cval);

		}
	    			
	    		/* 
	    		:: accvalue[accval-1] == 0 ->atomic{
	    			acccount[accval] ++;
	    			accvalue[accval-1] = 1; 

	    		}
	    		:: ac cvalue[accval-1] != 0   */


    //:: accmax >= QUORUM -> progress = true;

    od

}


proctype proposer(byte id; byte myval)
{
	coorproposal[leaderno] ! id,myval;
	if 
	::proposal[id] == 0 -> atomic{
		pcount++;
		proposal[id] = 1;
	}
      if
      :: pcount == PROPOSERS -> proposed = true;
      :: else -> skip;
      fi
    fi
}

proctype acceptor(byte id){
	byte crnd = 0,hrnd = 0,hval = 0;   //分别表示acceptor当前round号，接收value的最高round和对应的value
	short cval = 0;      //表示本轮接受的value，确保每轮值接收一个value；
	byte rnd,coorid;
	short val;
	do
	::  (acceptorpre[id] ? [coorid,rnd] && !progress)->  acceptorpre[id] ? coorid,rnd;  //acceptor查看prepare请求
		if					 
	    :: rnd > crnd ->atomic{
	    	crnd = rnd
	        promise[coorid] ! id,crnd,hrnd,hval
	    }
	    :: rnd < crnd ->atomic{                                           //若acceptor已参与更大的round，则发送通知信息
	    	prereply[coorid] ! crnd
	    }
	    fi;  
	::  (acceptoracc[id] ? [coorid,rnd,val] && !progress )->acceptoracc[id] ? coorid,rnd,val   //acceptor查看prepare请求
	    if
	    :: rnd == crnd ->                                   //和prepare阶段为同一轮
		   	if 
		  	:: val == -1 ->atomic{                          //acceptor若收到any message，则proposer向acceptor直接发送proposal
		   	    byte j;
		   	   /* for(j : 0..(PROPOSERS-1)){
		   	   	    proaccept(j, rnd, j+1);
		   	    }
		   	    j = 0;*/

		    }

	        :: val != -1 -> 
	        	if
	        	:: cval== 0 ->atomic{                      //判断acceptor在该轮是否已经接收过value，若没有，才可以接受
	        		crnd = rnd;
	        		cval = val;
	        		hrnd = rnd;
	        		hval = val;
	        		learnacc ! id, crnd, val;
	        		coordinatoracc[coorid] ! id, crnd, val;                                     
	        	}
	        	::else -> skip;                           //若已经接受过value，则忽略该value 
	        	fi                 
	        fi
	    :: rnd > crnd ->atomic{             //冲突恢复中直接开始的crnd+1轮
	    		crnd = rnd;
	        	cval = val;
	        	hrnd = rnd;
	        	hval = val;
	        	learnacc ! id, crnd, val;
	        	coordinatoracc[coorid] ! id, crnd, val;
	    }

	    :: rnd < crnd -> atomic{                                           //若acceptor已参与更大的round，则发送通知信息
	    	accreply[coorid] ! crnd


	    }
	    fi
	:: progress == true -> break;  
	od

}


proctype learner(){
	byte accid,accrnd,accval;  
	byte crnd = 0;
	byte cval;
	byte i,j;                   //acceptor接受的value
	byte acccount[PROPOSERS];           //用来保存每个value的接收次数
	byte accvalue[ACCEPTORS];   //用来判断是否已经接收过来自某个acceptor的信息
	byte acceptorscount = 0, accmax = 0;//分别表示已经接收了value的acceptor的个数和被接受次数最多的value的次数，用来判断是否会发生冲突，因为如果所有的acceptor都已经接收了value，却没有任何一个value的接受次数达到quorum，则有冲突
	byte maxvalue; //用来记录被接受次数最多的value值，即accmax对应的value
	do
	::accmax < QUORUM  -> 
	    if
		:: atomic{learnacc ? [accid,accrnd,accval] ->learnacc ? accid,accrnd,accval}          //learner查看已接受的value并进行计数
		    if 
		    :: crnd == 0 ->d_step{
		    	crnd = accrnd;
		    	acccount[accval-1] ++;
	    		accvalue[accid] = 1;
	    		if 
	    		:: acccount[accval-1] > accmax ->atomic{
	    			accmax = acccount[accval-1];
	    			maxvalue = accval;

	    		}
	    		fi

		    }
		    :: (crnd == accrnd && accvalue[accid] == 0) -> d_step{
		    	accvalue[accid] = 1;
		    	acccount[accval-1] ++;

		    }
		    :: (crnd != 0 && crnd < accrnd) -> d_step{               //若接收的round值大于当前round值，则更新round值并初始化所有计数
		    	for(i : 0 .. QUORUM-1){
		    		accvalue[i] = 0
		    	}
		    	i = 0;
		    	for(j : 0.. PROPOSERS-1){
		    		acccount[j] = 0;
		    	}
		    	j = 0
		    	accvalue[accid] =1;
		    	acccount[accval-1] ++;
		    	crnd = accrnd;
		    	accmax = acccount[accval-1];
	    		maxvalue = accval;
		    }
		    fi
		fi
    ::accmax >  QUORUM -> 
             if
             ::progress == true ->break;
             :: else ->
             atomic{
             	learned ! crnd,cval  ;          /*progress*/  //若同一value计数超过majority，则被learn
             	} 
             fi   
    //::progress == true ->break;                  
    od
}

 
init
{
	byte i,round,value;
	atomic{
		byte accvalue;
		run leader();
		leaderselected == true;
		for(i : 0 .. PROPOSERS-1){
			run proposer(i,i+1)
		}
		run coordinator(leaderno); 
		for(i : 0 .. ACCEPTORS-1){
			run acceptor(i);
		}
		run learner();
		learned ? round,value; 
	    progress = true;
		accvalue = value;
		/*do 
		:: learned ? [round,value] ->learned ? round,value;
		                             assert(value==accvalue);
		:: else -> break;
		od*/

		printf("%d\n",progress);
	}
}
