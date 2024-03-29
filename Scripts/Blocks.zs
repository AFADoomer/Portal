class BlockBase : SwitchableDecoration
{
	Vector3 spawnoffset;
	Vector3 offset;
	int pushtime;
	double oldpitch;
	double oldroll;
	Vector3 oldpos;
	bool inrange;
	int interval;
	bool dontcull, wasculled;

	transient CVar debug;
	bool dodebug;

	Default
	{
		+BRIGHT
		+NOGRAVITY
		+SOLID
		+SHOOTABLE
		+NOBLOOD
		+NOTAUTOAIMED
		+NODAMAGE
		+ALLOWPAIN
		+ACTLIKEBRIDGE
		+DONTTHRUST
		+INVISIBLE
		+THRUSPECIES
		Painchance 255;
		Radius 1;
		Height 1;
		Species "Block";
		RenderStyle "Add";
		Alpha 0.95;
	}
	
	States
	{
		Spawn:
			UNKN A -1 BRIGHT;
			Stop;
	}

	override void PostBeginPlay()
	{
		debug = Cvar.FindCVar("g_debugblocks");

		if (master)
		{
			A_SetSize(Radius * master.scale.x, Height * master.scale.y);
		}

		scale.x = Radius * 2.0;
		scale.y = Height * level.pixelStretch;

		if (master)
		{
			if (!wasculled)
			{
				spawnoffset = pos - master.pos;

				Vector2 temp = RotateVector((spawnoffset.x, spawnoffset.y), -master.angle);
				offset = (temp.x, temp.y, spawnoffset.z);

				temp = RotateVector((offset.x, offset.z), master.pitch);
				offset = (temp.x, offset.y, temp.y);

				temp = RotateVector((offset.y, offset.z), -master.roll);
				offset = (offset.x, temp.x, temp.y);

				spawnoffset = offset;

				if (!dontcull) { BlockManager.Add(self, spawnoffset); }
			}

			bSpecial = master.bPushable; // Only give SPECIAL if the master actor is pushable, since SPECIAL breaks collision.
		}

		if (pos.z < floorz) { Destroy(); }

		interval = Random(0, 15);
	}

	override void Tick()
	{
		if (!master || master.bStandstill) { Destroy(); return; }

		if (master && !master.bNoInteraction && !bDormant)
		{
			Rotate();

			if (!(master is "LaserCube"))
			{
				if (!bNoBlockMap && master.master && master.master is "PlayerPawn") { A_ChangeLinkFlags(1); }
				else if (bNoBlockMap) { A_ChangeLinkFlags(0); }
			}
		}

		if (debug && debug.GetBool())
		{
			dodebug = true;
			bInvisible = false;
		}
		else
		{
			dodebug = false;
			bInvisible = true;
		}

		Super.Tick();
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (master)
		{
			master.DamageMobj(inflictor, source, damage, mod, flags, angle);
			return 0;
		}

		return Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
	}

	override void OnDestroy()
	{
		A_RemoveChildren(TRUE, RMVF_MISC, "None", "BlockBase");	
	}

	void Rotate()
	{
		if (!master || spawnoffset == (0, 0, 0) || (master.pitch == oldpitch && master.roll == oldroll && master.pos == oldpos)) { return; }

		Vector2 temp;

		// Keep the blocks in the correct position, regardless of pitch/roll of the master actor
		// Obviously not perfect, because the blocks are rectangular, but close enough when you can't see them.
		temp = RotateVector((spawnoffset.y, spawnoffset.z + height / 2), master.roll);
		offset = (spawnoffset.x, temp.x, temp.y);

		temp = RotateVector((offset.x, offset.z), -master.pitch);
		offset = (temp.x, offset.y, temp.y);

		temp = RotateVector((offset.x, offset.y), master.angle);
		offset = (temp.x, temp.y, offset.z - height / 2);

		Vector3 dest = master.pos + offset;
		SetOrigin(dest, true);

		pushtime++;

		oldpitch = master.pitch;
		oldroll = master.roll;
		oldpos = master.pos;

		angle = angle - (angle % 90); // Blocks are square, so keep the angles aligned with the grid for debug purposes
	}

	override void Touch(Actor toucher)
	{
		if (master && master.bPushable && toucher is "PlayerPawn")
		{
			master.lastpush = pushtime;
			master.vel = toucher.vel * master.pushfactor;

			Rotate();
		}
	}
}

class BlockInfo
{
	BlockBase block;
	Class<actor> type;
	Vector3 position;
	Actor master;
	Vector3 spawnoffset;
	bool dormant;
	double range;
}

// Blocks get tracked in a dynamic array and culled when not in range of a player, then respawned when needed
class BlockManager : Thinker
{
	Array<BlockInfo> Blocks;
	int interval;

	static void Add(BlockBase block, Vector3 spawnoffset)
	{
		if (!block || spawnoffset == (0, 0, 0)) { return; }

		ThinkerIterator it = ThinkerIterator.Create("BlockManager", Thinker.STAT_Default);
		BlockManager manager = BlockManager(it.Next());

		if (!manager) { manager = new("BlockManager"); }

		if (!manager) { return; }

		manager.AddBlock(block, spawnoffset);
	}

	static void Remove(BlockBase block)
	{
		if (!block) { return; }

		ThinkerIterator it = ThinkerIterator.Create("BlockManager", Thinker.STAT_Default);
		BlockManager manager = BlockManager(it.Next());

		if (!manager) { manager = new("BlockManager"); }

		if (!manager) { return; }

		manager.RemoveBlock(block);
	}

	uint FindBlock(BlockBase block)
	{
		for (int i = 0; i < Blocks.Size(); i++)
		{
			if (Blocks[i] && Blocks[i].block && Blocks[i].block == block) { return i; }
		}
		return Blocks.Size();
	}

	void AddBlock(BlockBase block, Vector3 spawnoffset)
	{
		if (!block || spawnoffset == (0, 0, 0)) { return; }

		int i = FindBlock(block);
		if (i == Blocks.Size()) // Only add it if it's not already there somehow.
		{
			BlockInfo this = New("BlockInfo");
			this.block = block;
			this.type = block.GetClass();
			this.position = block.pos;
			this.master = block.master;
			this.spawnoffset = block.spawnoffset;
			this.dormant = block.bDormant;

			double range = 256.0;
			if (block.master) { range = max(range, block.master.renderradius * block.master.scale.x);}
			this.range = range;

			Blocks.Push(this);
		}
	}

	void RemoveBlock(BlockBase block)
	{
		if (!block) { return; }

		int i = FindBlock(block);
		if (i == Blocks.Size()) { return; }

		Blocks.Delete(i);
		block.Destroy();
	}

	override void Tick()
	{
		if (interval > 0) { interval--; return; }

		for (int i = 0; i < blocks.Size(); i++)
		{
			if (!blocks[i]) { continue; }

			bool inrange = false;

			for (int p = 0; p < MAXPLAYERS && !inrange; p++)
			{
				if (!playeringame[p]) { continue; }
				if (!blocks[i].master || blocks[i].master.master && blocks[i].master.master == players[p].mo) { continue; }

				if (
					(level.Vec3Diff(players[p].mo.pos, blocks[i].position)).length() < blocks[i].range ||
					(level.Vec3Diff(players[p].mo.pos, blocks[i].master.pos)).length() < blocks[i].range
				) { inrange = true; }
			}

			if (inrange && !blocks[i].block)
			{
				blocks[i].block = BlockBase(Actor.Spawn(blocks[i].type, blocks[i].position));
				if (blocks[i].block)
				{
					blocks[i].block.master = blocks[i].master;
					blocks[i].block.spawnoffset = blocks[i].spawnoffset;
					blocks[i].block.bDormant = blocks[i].dormant;
					blocks[i].block.wasculled = true;
				}
			}
			else if (!inrange && blocks[i].block)
			{
				blocks[i].block.Destroy();
			}
		}

		interval = 15;
	}
}

class Block8x8 : BlockBase { Default { Radius 4; Height 8; } }
class Block4x1 : BlockBase { Default { Radius 2; Height 1; } }
class Block6x1 : BlockBase { Default { Radius 3; Height 1; } }
class Block8x1 : BlockBase { Default { Radius 4; Height 1; } }
class Block12x1 : BlockBase { Default { Radius 6; Height 1; } }
class Block14x1 : BlockBase { Default { Radius 7; Height 1; } }
class Block16x1 : BlockBase { Default { Radius 8; Height 1; } }
class Block24x1 : BlockBase { Default { Radius 12; Height 1; } }
class Block32x1 : BlockBase { Default { Radius 16; Height 1; } }
class Block36x1 : BlockBase { Default { Radius 18; Height 1; } }
class Block42x42 : BlockBase { Default { Radius 21; Height 42; } }
class Step : BlockBase { Default { -SPECIAL; Radius 8; Height 1; } }

class RailBlock : BlockBase
{
	Default
	{
		Radius 1;
		Height 16;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();

		if (master && master is "WalkwaySegment" && WalkwaySegment(master).user_blockingrails)
		{
			A_SetSize(Radius, 26);
		}
	}
}

class DoorBlock : BlockBase
{
	Default
	{
		-SPECIAL;
		Radius 0;
		Height 64;
	}

	override void PostBeginPlay()
	{
		dontcull = true;

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		Super.Tick();

		if (master && master is "Pivot" && Pivot(master).door) { angle = Pivot(master).door.angle; }
	}
}