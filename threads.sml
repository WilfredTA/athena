structure Queue:
   sig
      type 'a t

      val new: unit -> 'a t
      val enque: 'a t * 'a -> unit
      val deque: 'a t -> 'a option
      val clear: 'a t -> unit 
   end =
   struct
      datatype 'a t = T of {front: 'a list ref, back: 'a list ref}

      fun new () = T {front = ref [], back = ref []}

      fun enque (T {back, ...}, x) = back := x :: !back

      fun deque (T {front, back}) =
         case !front of
            [] => (case !back of
                      [] => NONE
                    | l => let val l = rev l
                           in case l of
                              [] => raise Fail "deque"
                            | x :: l => (back := []; front := l; SOME x)
                           end)
          | x :: l => (front := l; SOME x) 
	  fun clear (T {front,back}) = (front := [];back := [])
   end

structure Thread:
   sig
      val exit: unit -> 'a
      val run: unit -> unit
      val spawn: (unit -> unit) -> unit
      val yield: unit -> unit
      val killAll: unit -> unit 

   end =

   struct
      open Posix.Signal
      open MLton
      open Itimer Signal Thread

      val topLevel: Thread.Runnable.t option ref = ref NONE

      local
         val threads: Thread.Runnable.t Queue.t = Queue.new ()
      in
         fun ready t = Queue.enque (threads, t)
         fun next () =
            case Queue.deque threads of
               NONE => valOf (!topLevel)
             | SOME t => t
	 fun clear() = Queue.clear threads 
      end
   
      fun 'a exit (): 'a = switch (fn _ => next ())
      
      fun new (f: unit -> unit): Thread.Runnable.t =
         Thread.prepare
         (Thread.new (fn () => ((f () handle _ => exit ())
                                ; exit ())),
          ())
         
      fun schedule t = (ready t; next ())

      fun yield (): unit = switch (fn t => schedule (Thread.prepare (t, ())))

      val spawn = ready o new

      fun killAll(): unit = switch (fn t => (clear(); next()))

      fun setItimer t =
         Itimer.set (Itimer.Real,
                     {value = t,
                      interval = t})

      fun run (): unit =
         (switch (fn t => 
                     (topLevel := SOME (Thread.prepare (t, ()));
                      new (fn () => (setHandler (alrm, Handler.handler schedule);
                                     setItimer (Time.fromMilliseconds 20)))));
         setItimer Time.zeroTime;
         ignore alrm;
         topLevel := NONE);


   end

