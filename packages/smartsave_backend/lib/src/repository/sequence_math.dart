/// Advances a uint16 sequence number, wrapping at 65535.
int next(int sequence) => (sequence + 1) & 0xffff;

/// Returns the forward uint16 distance from [from] to [to].
int distance(int from, int to) => (to - from) & 0xffff;

/// Whether [sequence] is at or before [reference] in uint16 sequence space.
bool isAtOrBefore(int sequence, int reference) =>
    distance(sequence, reference) < 0x8000;

/// Whether [nextSequence] immediately follows [previous] in uint16 space.
bool contiguous(int previous, int nextSequence) =>
    next(previous) == (nextSequence & 0xffff);
