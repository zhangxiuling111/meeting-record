## Consensus problems in distributed protocol

#### The starting point
Our starting point is Lamport's Paxos algorithm, which provides a textbook description on distributed consensus problem. The basic Paxos protocol solves simple consensus, i.e., to let multiple servers agree on a single value in asynchronous settings. Multi-Paxos can be used to solve the problem of how to maintain a replicated state machine, in the way that multiple servers agree on the same log of actions or events. In an asynchronous setting a message can take arbitrarily long to be delivered, can be duplicated and can be lost.

#### Basic Paxos has three distinguished roles
- Proposers who propose values in parallel
- Acceptors who accept or vote for the values proposed by the proposers
- Learners who observes the chosen value which is agreed by a majority of the acceptors

With possibilities of only non-Byzantine failures (i.e., a server operate at arbitrary speed, it may honestly crash, and may re-start after breaking down, but it cannot act maliciously by e.g., faking a message), basic Paxos maintains safety with failures of up to n acceptors (n is also known as the size of a quorum) in a 2n+1 acceptors setting.

#### Problem of interest

Safety and liveness are two important classes of properties. 

The safety properties for Paxos includes:
- Nontriviality: only proposed values can be learned
- Consistency: At most one value can be learned (in each round)

Progress is not guaranteed due to existence of livelock with the presence of multiple proposers. Some interesting examples can be found at https://en.wikipedia.org/wiki/Paxos_(computer_science). Efficiency may be improved if we assume a single proposer and a single learner, so that progress may be guaranteed in revised versions of the orginal (basic) Paxos. However, even with an initial leader election, liveness is theoretially infeasible due to the result of Fischer, Lynch and Paterson (JACM 1985, available at https://groups.csail.mit.edu/tds/papers/Lynch/jacm85.pdf).

#### Extensions and variants of Paxos

Some interesting variants of Paxos include fast Paxos, speculative Paxos, Raft.

A few implemented versions of Paxos must be modified or adapted in their particular environments, such as ZooKeeper (of Apache Hadoop https://zookeeper.apache.org), Chubby of Google's BigTable (http://blogoscoped.com/archive/2008-07-24-n69.html).

#### Our methodologies

Manual analysis of a given protocol is always used. We also intend to apply model checking (such as in the tool SPIN http://spinroot.com/) to verify a property in temporal logics.

#### Other related interesting works


