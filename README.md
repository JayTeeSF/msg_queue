
Per O'Reilly's "Using C on the Unix System" (p135 on msg_queues)
and Peter C's gist (making Sys V queue's work for Ruby 1.9x on OsX)

Cool online reference to code that looks similar to my O'Reilly book:
https://www.cs.cf.ac.uk/Dave/C/node25.html

Learn you some message queues:
http://space.wccnet.edu/~chasselb/linux275/ClassNotes/ipc/msgQ.htm

Minor adjustments:
List your queues: ipcs -q

Grab each q's ID:
ipcs -q | grep "$USER"| awk '{print $2}'

remove those queues:
ipcrm -q 65537

