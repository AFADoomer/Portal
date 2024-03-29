class Pivot : Actor
{
	Class<SwingingDoor> doorclass;
	Class<DoorFrame> doorframe;
	SwingingDoor door;
	BlockBase blockers[32];
	Actor frame;
	double spawnangle;
	double targetangle;
	double user_startangle;
	double maxangle;
	Line linedef;

	Property DoorClass:doorclass;
	Property FrameClass:doorframe;
	Property OpenAngle:maxangle;

	Default
	{
		//$Category Portal/Doors
		//$Title Door Frame (Green Door)
		+NOINTERACTION
		Height 0;
		Radius 0;
		Speed 6;
		Pivot.DoorClass "SwingingDoor";
		Pivot.FrameClass "DoorFrame";
		Pivot.OpenAngle 90;
	}

	States
	{
		Spawn:
			UNKN A -1;
			Stop;
	}

	override void PostBeginPlay()
	{
		bInvisible = true;
		bDormant = SpawnFlags & MTF_DORMANT;

		spawnangle = angle;

		if (user_startangle) { angle -= user_startangle; }

		targetangle = angle;

		While (doorframe && !frame)
		{
			frame = Spawn(doorframe, pos);
			if (frame)
			{
				frame.angle = spawnangle + 90;
				frame.master = self;
			}
		}

		While (!door)
		{
			door = SwingingDoor(Spawn(doorclass, (pos.xy + RotateVector((16, 0), angle), pos.z)));
			if (door)
			{
				door.angle = angle - 90;
				door.master = self;

				linedef = Utilities.GetCurrentLine(door);
			}
		}

		for (int i = 2; i <= 30; i+=2)
		{
			While (!blockers[i])
			{
				blockers[i] = BlockBase(Spawn("DoorBlock", (pos.xy + RotateVector((i, 0), angle), pos.z)));
				if (blockers[i])
				{
					blockers[i].master = self;
					blockers[i].A_SetSize(-1, door.height);
					BlockBase(blockers[i]).dontcull = true;
				}
			}
		}
	}

	override void Tick()
	{
		if (bDormant) { return; }

		Super.Tick();

		if (angle != targetangle)
		{
			for (int i = 2; i <= 30; i+=2)
			{
				if (blockers[i] && !blockers[i].CheckPosition(pos.xy + RotateVector((i, 0), angle)))
				{
					targetangle = angle;
					return;
				}
			}		

			if (angle > targetangle) { angle = max(angle - Speed, targetangle); }
			else if (angle < targetangle) { angle = min(angle + Speed, targetangle); }

			if (targetangle == spawnangle && angle >= spawnangle - Speed && angle < spawnangle)
			{
				A_StartSound(door.close, CHAN_AUTO, CHAN_NOSTOP, 0.5);
			}

			door.SetXYZ((pos.xy + RotateVector((16, 0), angle), pos.z));
			door.angle = angle - 90;

			if (linedef)
			{
				if (angle >= spawnangle - 35)
				{
					linedef.flags |= (Line.ML_BLOCKEVERYTHING | Line.ML_BLOCKSIGHT);
				}
				else
				{
					linedef.flags &= ~(Line.ML_BLOCKEVERYTHING | Line.ML_BLOCKSIGHT);
				}
			}

			for (int i = 2; i <= 30; i+=2)
			{
				if (blockers[i]) { blockers[i].SetOrigin((pos.xy + RotateVector((i, 0), angle), pos.z), true); }
			}
		}
	}
}

class PivotWhite : Pivot
{
	Default
	{
		//$Title Door Frame (White Door)
		Pivot.DoorClass "SwingingDoorWhite";
	}
}

class PivotChainLink : Pivot
{
	Default
	{
		//$Title Chain Link Door
		Pivot.DoorClass "SwingingDoorChainLink";
		Pivot.FrameClass "DoorFrameChainLink";
		Pivot.OpenAngle 135;
	}
}

class DoorFrame : Actor
{
	Default
	{
		+NOINTERACTION
		Radius 0;
		Height 0;
	}

	States
	{
		Spawn:
			UNKN A -1;
			Stop;
	}	
}

class DoorFrameChainLink : DoorFrame {}

class SwingingDoor : Actor
{
	int lastuse;
	Sound open, close, locked;

	Property OpenSound:open;
	Property CloseSound:close;
	Property LockedSound:locked;

	Default
	{
		+WALLSPRITE
		+NOGRAVITY
		-SOLID
		+SPECIAL
		+INTERPOLATEANGLES
		Radius 16;
		Height 64;
		SwingingDoor.OpenSound "door2/open";
		SwingingDoor.CloseSound "door2/close";
		SwingingDoor.LockedSound "door2/locked";
	}

	States
	{
		Spawn:
			UNKN A -1;
			Stop;
		Open:
			UNKN B 15;
			Goto Spawn;
	}

	override void Touch(Actor toucher)
	{
		Super.Touch(toucher);

		if (!master || !Pivot(master) || angle == Pivot(master).spawnangle - 90) { return; }

		double da = abs(deltaangle(toucher.angle, master.angle));
		if (da < 45 || da > 135) { return; }

		double maxangle = master.spawnangle;
		double minangle = maxangle - Pivot(master).maxangle;

		if (master.angle >= minangle && master.angle <= maxangle)
		{
			double dist = Distance2D(toucher);
	
			Vector2 amt = toucher.vel.xy * clamp(dist, 1, 32) / 32;

			double delta = toucher.vel.xy.length() * toucher.Speed * 4;
			if (abs(deltaangle(toucher.angle, angle)) < Pivot(master).maxangle) { delta *= -1; }

			Pivot(master).targetangle = clamp(Pivot(master).targetangle + delta, minangle, maxangle);
		}
	}

	override bool Used(Actor user)
	{
		if (!master || !Pivot(master) || level.time - lastuse <= 5) { return false; }

		if (Pivot(master).angle == Pivot(master).spawnangle)
		{
			if (master.bDormant) { A_StartSound(locked, CHAN_AUTO, 0, 0.5); }
			else { A_StartSound(open, CHAN_AUTO, 0, 0.5); }
			SetStateLabel("Open");
		}

		if (Pivot(master).targetangle < Pivot(master).spawnangle)
		{
			Pivot(master).targetangle = Pivot(master).spawnangle;
		}
		else
		{
			Pivot(master).targetangle = Pivot(master).spawnangle - Pivot(master).maxangle;
		}

		lastuse = level.time;

		return true;
	}
}

class SwingingDoorWhite : SwingingDoor {}

class SwingingDoorChainLink : SwingingDoor
{
	Default
	{
		Height 60;
		SwingingDoor.OpenSound "doorchainlink/open";
		SwingingDoor.CloseSound "doorchainlink/close";
		SwingingDoor.LockedSound "doorchainlink/locked";
	}
}

class SlidingDoor : Actor
{
	Array<Actor> Activators;
	bool active, moving, blocked, closed, user_startopen;
	int activationradius, activationtime, holdtime;
	Line linedef;
	Sound open, close;

	Property ActivationRadius:activationradius;
	Property HoldTime:holdtime;
	Property OpenSound:open;
	Property CloseSound:close;

	Default
	{
		//$Category Portal/Doors
		//$Title Sliding Door
		+DONTTHRUST
		Height 64;
		Radius 20;
		SlidingDoor.ActivationRadius 64;
		SlidingDoor.OpenSound "elevator/door/open";
		SlidingDoor.CloseSound "elevator/door/close";
		SlidingDoor.HoldTime 140;
	}

	States
	{
		Open:
			UNKN A 4;
			UNKN A 4 SetLines();
			UNKN B 8 A_StartSound(open, CHAN_AUTO, 0, 0.5, ATTN_STATIC);
			UNKN C 6;
			UNKN DE 4;
		Opened:
			UNKN F -1 { moving = false; }
			Stop;
		Close:
			UNKN FE 8;
			UNKN D 4 SetLines();
			UNKN C 4 A_StartSound(close, CHAN_AUTO, 0, 0.5, ATTN_STATIC);
			UNKN B 2;
		Spawn:
		Closed:
			UNKN A -1 { moving = false; }
			Stop;
	}

	override void PostBeginPlay()
	{
		linedef = Utilities.GetCurrentLine(self);
	
		if (user_startopen) { active = true; SetStateLabel("Opened"); }
		else if (linedef) { linedef.flags  |= (Line.ML_BLOCKEVERYTHING | Line.ML_BLOCKSIGHT); }

		Super.PostBeginPlay();
	}

	override bool Used(Actor user)
	{
		if (bDormant) { return false; }

		SetPeerState(!active);

		return true;
	}

	override void Activate(Actor activator)
	{
		if (!active) { SetPeerState(true); }
	}

	override void Deactivate(Actor activator)
	{
		if (active) { SetPeerState(false); }
	}

	override void Tick()
	{
		if (bDormant)
		{
			Super.Tick();
			return;
		}

		blocked = false;

		GetActivators(ActivationRadius);

		for (int i = 0; i < Activators.Size(); i++)
		{
			if (Activators[i])
			{
				let mo = Activators[i];
				let p = mo.player;

				if (mo.health <= 0 || !mo.bShootable) { Activators.Delete(i); continue; }

				double dist = Utilities.DistanceFromLine(mo, linedef);

				if (dist < (bStandStill ? mo.radius : activationradius))
				{
					if (!bStandStill) { Activate(mo); }
					blocked = true; // Don't move the door while you're in the doorway...
				}
			}
		}

		if (activationtime >= 0)
		{
			activationtime = max(0, activationtime - 1);
			if (activationtime == 0) { Deactivate(null); }
		}

		Super.Tick();
	}

	void SetPeerState(bool makeactive = true)
	{
		if (moving || blocked) { return; }

		if (tid)
		{ // If there's a TID, affect all actors with that TID
			let it = level.CreateActorIterator(tid, "SlidingDoor");
			SlidingDoor mo;

			while (mo = SlidingDoor(it.Next()))
			{
				DoActivation(mo, makeactive);
			}
		}

		DoActivation(self, makeactive);
	}

	void DoActivation(SlidingDoor mo, bool makeactive)
	{
		if (mo.blocked || mo.moving) { return; }

		mo.active = makeactive;
		mo.moving = true;

		if (makeactive)
		{
			mo.activationtime = holdtime;
			mo.SetStateLabel("Open");
		}
		else
		{
			mo.activationtime = -1;
			mo.SetStateLabel("Close");
		}
	}

	private void SetLines()
	{
		if (linedef)
		{
			if (!active)
			{
				linedef.flags |= (Line.ML_BLOCKEVERYTHING | Line.ML_BLOCKSIGHT);
			}
			else
			{
				linedef.flags &= ~(Line.ML_BLOCKEVERYTHING | Line.ML_BLOCKSIGHT);
			}
		}
	}

	void GetActivators(double range = 64, double doorheight = 96)
	{
		BlockThingsIterator it = BlockThingsIterator.Create(self, range);

		while (it.Next())
		{
			if (!it.thing.bIsMonster && !(it.thing is "PlayerPawn")) { continue; } // Ignore everything except players and monsters
			if (
				(Utilities.DistanceFromLine(it.thing, linedef) > range + it.thing.radius) || // Check if the actor can reach the door
				(it.thing.pos.z + it.thing.height < pos.z) || // Z-height check (player below door)
				(it.thing.pos.z > pos.z + doorheight) // Z-height check (player above door)
			)
			{
				if (Activators.Find(it.thing) != Activators.Size()) // If the actor was already on the Activators list
				{
					Activators.Delete(Activators.Find(it.thing)); // ...delete it from the Activators list.  
					Activators.ShrinkToFit(); // Re-shrink the array
				}
				continue;
			}

			if (Activators.Find(it.thing) == Activators.Size()) { Activators.Push(it.thing); } // Add the actor to the list of Activators if it's not already there
		}
	}

}