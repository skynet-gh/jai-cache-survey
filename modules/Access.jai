#module_parameters(BASELINE : bool, SIZE : u64, N : u64, SHUFFLE : bool);

Elem :: struct {
  next : *Elem;
}

array : [SIZE] Elem;

bench :: () -> u64 {
  for i : 0..SIZE-2 {
    array[i].next = *array[i + 1];
  }
  array[SIZE - 1].next = *array[0];

  // shuffle
  #if SHUFFLE {
    for i : 0..SIZE-1 {
      j := i + (random_get() % (SIZE - i));
      temp := array[i];
      array[i] = array[j];
      array[j] = temp;
    }
  }

  #if !BASELINE {
    dummy : u64 = 0;

    i := array[0];
    for n : 0..N-1 {
      dummy += cast(u64) i.next;
      i = i.next;
    }

    return dummy;
  }

  return 0;
}

#import "Basic";
#import "Random";
