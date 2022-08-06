N : u64 : 10_000_000;

#module_parameters(BASELINE := false, SIZE : u64 = 1024);

Elem :: struct {
  next : *Elem;
}

array : [SIZE] Elem;

bench :: () {
  for i : 0..SIZE-2 {
    array[i].next = *array[i + 1];
  }
  array[SIZE - 1].next = *array[0];

  // shuffle
  for i : 0..SIZE-1 {
    j := i + (random_get() % (SIZE - i));
    temp := array[i];
    array[i] = array[j];
    array[j] = temp;
  }

  #if !BASELINE {
    dummy : u64 = 0;

    i := array[0]; 
    for n : 0..N-1 {
      dummy += cast(u64) i.next;
      i = i.next;
    }
    log("%\n", dummy);
  }
}

#import "Basic";
#import "Random";
