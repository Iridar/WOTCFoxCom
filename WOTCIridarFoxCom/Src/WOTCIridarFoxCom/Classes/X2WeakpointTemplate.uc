class X2WeakpointTemplate extends X2CharacterTemplate;

var name OwnerTemplate;
var name SocketName;

var delegate<OnWeakpointDamaged> OnWeakpointDamagedFn;
var delegate<OnWeakpointDestroyed> OnWeakpointDestroyedFn;

delegate OnWeakpointDamaged(XComGameState_Unit WeakpointState);
delegate OnWeakpointDestroyed(XComGameState_Unit WeakpointState);
