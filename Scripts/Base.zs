class PortalActor : Actor
{
	int user_variant;
	bool user_blockingrails;
	String stepsound;

	Property StepSound:stepsound;

	States
	{
		Spawn:
			UNKN A -1;
			Stop;
	}

	override void PostBeginPlay()
	{
		bDormant = SpawnFlags & MTF_DORMANT;
		bNoGravity = bStandStill ? true : Default.bNoGravity;
		bNoInteraction = bStandStill ? true : Default.bNoInteraction;
		bSolid = bStandStill ? false : Default.bSolid;
		
//		A_ChangeLinkFlags(bStandStill || Default.bNoBlockMap);

		if (!bSolid && bNoInteraction) { A_SetSize(0, 0); }
		else
		{
			A_SetSize(Default.Radius * scale.x, Default.Height * scale.y); // This sets based on UDMF scale properties
			mass = int(mass * scale.x);
		}

		if (!bStandStill) { SpawnBlocks(); }

		frame = user_variant;

		Super.PostBeginPlay();
	}

	void OffsetRelative(Actor mo, double xoffset = 0, double yoffset = 0, double zoffset = 0)
	{
		if (!mo) { return; }

		Vector2 temp;
		Vector3 offset;

		temp = RotateVector((yoffset, zoffset), roll);
		offset = (xoffset, temp.x, temp.y);

		temp = RotateVector((offset.x, offset.z), -pitch);
		offset = (temp.x, offset.y, temp.y);

		temp = RotateVector((offset.x, offset.y), angle);
		offset = (temp.x, temp.y, offset.z);

		offset.x *= scale.x;
		offset.y *= scale.x;
		offset.z *= scale.y;

		mo.SetOrigin(pos + offset, true);
	}

	virtual void SpawnBlocks() {}
}

class CarryActor : PortalActor
{
	Vector3 oldpos;
	double oldangle;
	double spawnheight, spawnradius;
	Sound slidesound;
	Array<Actor> touchers;
	Vector3[64] offsets;
	bool fizzle, explode;
	int interval, fizzletime;
	bool crushed;
	bool initialized;
	int waterstate;
	double zoffset, heightoffset;
	double rollvel, pitchvel;
	Actor onmobj, oldonmobj;
	BlockBase block;
	bool onground, centermodel;
	Vector2 spawnscale;

	Property SlideSound:slidesound;
	Property Fizzle:fizzle;
	Property Explode:explode;
	Property CenterModel:centermodel;

	Default
	{
		//$Category Portal/Objects/Carryable
		+ALLOWBOUNCEONACTORS
		+BOUNCEONACTORS
		+MBFBOUNCER
		+BOUNCEAUTOOFF
		+SLIDESONWALLS
		+PUSHABLE
		+WINDTHRUST
		+SOLID
		+CANPASS
		+SHOOTABLE
		+NOBLOOD
		+NOTAUTOAIMED
		+NODAMAGE
		BounceType "Grenade";
		BounceFactor 0.05;
		BounceSound "cube/bounce";
		WallBounceSound "cube/bounce";
		Health 35;
		DamageFactor "Crush", 4.0;
		CarryActor.SlideSound "cube/slide";
		CarryActor.Fizzle False;
		CarryActor.Explode False;
		CarryActor.CenterModel True;
	}

	States
	{
		Fizzle:
			UNKN A 1;
			UNKN A 0 {
				Utilities.Fizzle(self);

				if (fizzletime++ < 70)
				{
					A_AttachLight("FizzlerIndicator", DynamicLight.PointLight, 0x00000000, int(radius * (1.0 - (fizzletime / 70.0))), 0, DYNAMICLIGHT.LF_ATTENUATE);
					SetStateLabel("Fizzle");
				}
			}
			Stop;
		Death:
			UNKN # 1 {
				if (explode) { SetStateLabel("Death.Explode"); }
				A_NoBlocking();
			}
			UNKN # -1;
			Stop;
		Death.Crush:
			UNKN # 1;
			UNKN # 0 {
				if (explode) { SetStateLabel("Death.Explode"); }
/*
				else if (scale.y * spawnheight > 9.0)
				{
					double newscale = (ceilingz - floorz) / spawnheight;
					if (newscale < scale.y)
					{
						scale.y = newscale;
						scale.x = max(1.0, 1.0 / (newscale * 3));
						A_SetSize(spawnradius * scale.x, spawnheight * scale.y);
					}

					SetStateLabel("Death.Crush");
				}
*/
			}
			UNKN # -1;
			Stop;
		Death.Explode:
			UNKN # 4 {
				Actor debris = Spawn("DebrisSpawner", pos);
				if (debris) { debris.master = self; }

				bNoGravity = true;
				scale.y *= 0.9;
				scale.x *= 1.1;
				SetOrigin(pos + (0, 0, 0.2 * height), true);

				frame++;
			}
			UNKN # 2 {
				scale.y *= 0.8;
				scale.x *= 1.2;
				SetOrigin(pos + (0, 0, 0.4 * height), true);

				Actor explosion = Spawn("Explosion", pos);
				if (explosion) { explosion.master = self; }
			}
			Stop;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER);

		A_SetSize(radius * scale.x, height / 2 * scale.y); // This sets based on Default scale properties
		interval = Random(0, 9);

		if (fizzle) { A_AttachLight("FizzlerIndicator", DynamicLight.PointLight, 0x00000000, int(radius * 1.5), 0, DYNAMICLIGHT.LF_ATTENUATE); }
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		spawnheight = height;
		spawnradius = radius;
		spawnscale = scale;

		bPushable = !bStandStill && !bDormant;

		pushfactor = double(100) / mass;

		if (scale.x > 1.5 || scale.y > 1.5) { bPushable = false; }

		gravity = 0.5;
	}

	override void Tick()
	{
		if (IsFrozen() || bDormant) { return; }

		if (!initialized && level.time - SpawnTime > 35 && vel.length() == 0)
		{
			gravity = Default.gravity;
			initialized = true;
		}

		if (centermodel) { zoffset = abs(spawnradius * sin(pitch) * sin(roll)) + abs(spawnheight / 2 * cos(pitch) * cos(roll)) + heightoffset; }
		else { zoffset = 0; }

		if (!fizzle && pos.z <= floorz + zoffset && floorpic == skyflatnum)
		{
			ClearBounce();

			scale *= 0.9;

			if (Scale.X < 0.05) { Destroy(); return; }
		}

		if (fizzle) { Utilities.CheckFizzle(self, "Fizzle"); }
		else
		{
			// One-time water entry/exit splashes
			if (waterlevel > 0 && waterstate == 0) { A_StartSound("world/water/enter", 8, 0, 0.005 * mass / 100.0 * abs(vel.z)); }
			else if (waterlevel == 0 && waterstate > 0) { A_StartSound("world/water/exit", 8, 0, 0.005 * mass / 100.0 * abs(vel.z)); }

			waterstate = waterlevel;
		}

		oldangle = angle;

		Super.Tick();

		onmobj = Utilities.FindOnMobj(self, zoffset);

		if (pos == oldpos && angle == oldangle && onmobj == oldonmobj) { return; }

		angle = oldangle;

		if (master is "Launcher")
		{
			if (!vel.z || pos.z == ceilingz - height)
			{
				gravity = Default.gravity;
				master = null;
			}
		}

		// Handling so that bounce sound doesn't play if the object didn't move 
		// or when it's being carried, and so that the angle doesn't stutter when
		// the object is pushed but cannnot move.
		if (pos == oldpos || (master is "PlayerPawn") || waterlevel)
		{
			bNoBounceSound = true;
		}
		else
		{
			bNoBounceSound = false;
		}

		double volume = 0.0;
		double floorheight = max(curSector.NextLowestFloorAt(pos.x, pos.y, pos.z), floorz) + zoffset;

		if (health > 0 && (pos.z <= floorheight) && !waterlevel) { volume = vel.xy.length() / 25; }

		if (volume)
		{
			A_StartSound(slidesound, CHAN_5, CHANF_LOOP | CHANF_NOSTOP, volume);
			A_SoundVolume(CHAN_5, volume);
		}
		else
		{
			A_StopSound(CHAN_5);
		}

		oldpos = pos;

		// Stackable movable objects
		if (level.time % 10 == interval) { CheckTouchers(); }

		for (int i = 0; i < touchers.Size(); i++)
		{
			if (touchers[i] && touchers[i] != master)
			{
				if (
					Distance3D(touchers[i]) > (Radius + touchers[i].radius) * 2.0 ||
					touchers[i].pos.z < pos.z + height
				) { touchers.Delete(i); }
				else { offsets[i] = touchers[i].pos - pos; }
			}
			else
			{
				touchers.Delete(i);
				touchers.ShrinkToFit();
			}
		}

		pitchvel = vel.z * sin(pitch);

		if (master && master is "PortalPlayer")
		{
			if (PortalPlayer(master).DragTarget == self)
			{
				pitch = 0; //master.pitch;
				pitchvel = vel.z * sin(master.pitch);
				roll = master.roll;

				return;
			}
		}

		for (int i = 0; i < touchers.Size(); i++)
		{
			if (
				touchers[i] && 
				(
					(Distance2D(touchers[i]) < (Radius + touchers[i].radius) * 1.4 && touchers[i].pos.z == pos.z + height) ||
					deltaangle(angle, AngleTo(touchers[i])) < 45 ||
					(touchers[i].bOnMobj && Distance3D(touchers[i]) < radius * 2)
				)
			)
			{
				if (!(touchers[i] is "PlayerPawn") && touchers[i].pos.z == pos.z + height) { touchers[i].vel = vel; }
				else if (touchers[i].CheckMove(pos.xy + offsets[i].xy)) { touchers[i].SetOrigin(pos + offsets[i], true); }
				else if (touchers[i].pos.z < pos.z + height + zoffset) { touchers[i].DamageMobj(self, self, int(max(Speed, 0.5) * vel.length()), "Crush"); }
			}
		}

		Vector2 relmove = RotateVector(vel.xy, -angle);
		rollvel = relmove.y;

		if (onmobj)
		{
			floorheight = onmobj.pos.z + onmobj.height + zoffset;
		}

		oldonmobj = onmobj;

		if (pos.z <= floorheight || onmobj)
		{
			if (vel.length() < 0.05)
			{
				vel *= 0;
			}
			else
			{
				vel.xy *= 0.4;
				vel.z = 0.0;
			}

			if (radius != spawnradius || height != spawnheight - zoffset)
			{
				A_SetSize(spawnradius, spawnheight - zoffset, true); // Reset the size
			}

			if (master && (master is "Launcher")) { master = null; }

			Vector3 newpos = (pos.xy, max(pos.z, floorheight));
			if (pos != newpos) { SetOrigin(newpos, false); }

			if (!block && zoffset)
			{
				block = BlockBase(Spawn("BlockBase", (pos.xy, floorheight - zoffset)));
				if (block)
				{
					block.master = self;
					block.dontcull = true;
					block.bActLikeBridge = false;
				}
			}

			if (block && (block.radius != spawnradius || block.height != zoffset))
			{
				block.A_SetSize(spawnradius, zoffset, false);
				block.scale.x = spawnradius * 2.0;
				block.scale.y = zoffset * level.pixelStretch;
			}
		}
		else
		{
			pitch = Normalize180(pitch - pitchvel);
			roll = Normalize180(roll - rollvel);

			if (!master || !(master is "Launcher"))
			{
				if (vel.z > 0) { vel *= 0.8; }
				else { vel *= 1.00125; }
			}
		}

		if (pos.z <= floorheight && !onground)
		{
//			PitchRollManager.Add(self);
			pitch = 0;
			roll = 0;
			onground = true;
		}
		else if (pos.z > floorheight) { onground = false; }
	}

	override void Touch(Actor toucher)
	{
		if (Distance2D(toucher) > (Radius + toucher.Radius) * 1.4) { return; }
		if (toucher == self || toucher == toucher.master || toucher.bNoGravity) { return; }
		if (toucher.pos.z > pos.z + height || toucher.pos.z <= pos.z - zoffset) { return; }
		if (touchers.Find(toucher) == touchers.Size()) { touchers.Push(toucher); }
	}

	void CheckTouchers()
	{
		BlockThingsIterator it = BlockThingsIterator.Create(self, Radius);
		Actor mo;

		while (it.Next() && (mo = it.thing))
		{
			if (mo.bSolid && !mo.bNoInteraction && mo.bPushable && mo is "CarryActor") { Touch(mo); }
		}
	}

	override void OnDestroy()
	{
		A_StopSound(CHAN_5);
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (source && source is "PlayerPawn" && damage == 1000000 && mod == '') // Assume this is the mdk cheat...
		{
			damagefactor = 1.0;
			return Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		}

		if (mod == "Crush" && damage > 1.0)
		{
			if (block)
			{
				block.Destroy();
			}

			double newscale = (ceilingz - floorz) / spawnheight;

			if (newscale < scale.y)
			{
				scale.y = spawnscale.y * newscale;
				scale.x = max(spawnscale.x, spawnscale.x / (newscale * 3));
				A_SetSize(spawnradius * scale.x, spawnheight * scale.y, false);

				spawnheight = height;
			}
		}

		if (explode) { return Super.DamageMobj(inflictor, source, damage, mod, flags, angle); }

		return 0;
	}

	override bool CanCollideWith(Actor other, bool passive)
	{
		if (other == block || (other is "BlockBase" && other.master == self)) { return false; }

		return true;
	}
}