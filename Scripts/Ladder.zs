class LadderBase : Actor
{
	Array<Actor> Climbers;
	double ladderheight;
	double climbradius;
	double friction;
	bool passive;
	bool nomonsters;
	int soundtimeout;
	int user_soundtype;

	Property LadderHeight:ladderheight; // Height of climbable area
	Property DisallowMonsters:nomonsters; // Can monsters climb the ladder?
	Property ClimbRadius:climbradius; // Detection radius for the ladder.  Defaults to same as actor radius
	Property Friction:friction;

	Default
	{
		+DONTTHRUST
		+NODAMAGE
		+NOGRAVITY
		-SOLID
		+NOINTERACTION
		Height 8;
		Radius 24;
		LadderBase.LadderHeight 132; // Uses custom property vice actual actor height so that the ladder model can be submerged in the ground to make shorter ladders 
		LadderBase.DisallowMonsters True; // Sets variable determining if monsters should be disallowed from using the ladder
		LadderBase.Friction 0.95; // Only slow down a little when climbing ladders, by default
	}

	States
	{
		Spawn:
			UNKN A 1;
			Loop;
	}

	override void PostBeginPlay()
	{
		if (!bStandStill)
		{
			if (!climbradius) { climbradius = Radius; }

			A_SetSize(radius * scale.x, height * scale.y);
			climbradius *= scale.x;

			Climbers.Clear();

			DoStackCheck();
		}
		else
		{
			A_SetSize(Radius, height / 3); // Minimal height if passive scenery, but enough to walk on, still
		}

		Super.PostBeginPlay();
	}

	void DoStackCheck()
	{
		BlockThingsIterator it = BlockThingsIterator.Create(self, 1);

		while (it.Next())
		{
			if (it.thing == self) { continue; } // Ignore itself

			if (it.thing is "LadderBase")
			{ // If there are other ladders immediately above or below, handle setting up transfer logic so that players don't get dropped mid-ladder if there are multiple stacked ladders
				if (Distance2d(it.thing) > 0) { continue; } // Only check ladders that are directly above/below this one

				if (it.thing.pos.z > pos.z && it.thing.pos.z - LadderBase(it.thing).ladderheight <= pos.z) { passive = true; } // This ladder is not the top, so make it decorative only
				else if (it.thing.pos.z < pos.z && pos.z - ladderheight <= it.thing.pos.z) // This ladder is the top, so make its height check logic handle the entire stack
				{
					double heightcheck = pos.z - it.thing.pos.z + LadderBase(it.thing).ladderheight;
					ladderheight = heightcheck > ladderheight ? heightcheck : ladderheight;
				}
			}
		}
	}

	override void Tick()
	{
		Super.Tick();

		if (passive || bStandStill) { return; }

		BlockThingsIterator it = BlockThingsIterator.Create(self, climbradius + 16);

		while (it.Next())
		{
			if ((nomonsters || !it.thing.bIsMonster) && !(it.thing is "PlayerPawn")) { continue; } // Ignore everything except players and monsters

			if (
				(Distance2D(it.thing) > (climbradius + it.thing.radius) * 1.34 || !CheckSight(it.thing)) || // Check if the actor can reach the ladder (horizontal radius check), with some fudging to account for square collision boxes
				(it.thing.pos.z + it.thing.height < pos.z - ladderheight) || // Z-height check (player below ladder)
				(it.thing.pos.z > pos.z + (bSolid ? height : -height)) // Z-height check (player above ladder) - if non-solid, the player will "step down" onto the ladder, so it's easier to get onto ladders that are in a hole in the ground
			)
			{
				ResetActor(it.thing);
				continue;
			}

			if (!it.thing.bFly && !it.thing.bFloat) // Only affect things that aren't already flying
			{
				if (Climbers.Find(it.thing) == Climbers.Size()) { Climbers.Push(it.thing); } // Add the actor to the list of climbers if it's not already there

				if (it.thing.bIsMonster) { it.thing.bFloat = True; } // If it's a monster set +FLOAT
				else
				{
					if (it.thing is "PortalPlayer")
					{
						if (PortalPlayer(it.thing).DragTarget) // Don't allow climbing while carrying something
						{
							ResetActor(it.thing);
							return;
						}
						PortalPlayer(it.thing).climbing = self; // Store pointer to the ladder object in player variable
					}
					else { it.thing.bFly = True; } // If it's some other class of player, use the fly cheat/powerup
				}
				it.thing.bNoGravity = True;
			}

			if (Climbers.Find(it.thing) < Climbers.Size()) // If the actor is in the climbers list, apply speed/velocity changes
			{
				it.thing.vel *= friction;
			}

			double vel = abs(it.thing.vel.length());

			if (soundtimeout <= 0 && vel / friction >= 1.0 && it.thing.pos.z > it.thing.floorz)
			{
				double vol = min(vel / friction - 1.0, 1.0);

				it.thing.A_StartSound("footsteps/ladder", CHAN_BODY, 0, vol * 0.05);

				soundtimeout = int(15 / friction);
			}
		}

		soundtimeout--;
	}

	// Restores the default values of the various flags if the actor was on this ladder
	void ResetActor(Actor mo)
	{
		if (Climbers.Find(mo) != Climbers.Size()) //If the actor was on the list of climbers for this ladder...
		{
			mo.Speed = mo.Default.Speed; // Reset the default values...
			mo.bNoGravity = mo.Default.bNoGravity;
			mo.bFly = mo.Default.bFly;
			mo.bFloat = mo.Default.bFloat;

			if (mo is "PortalPlayer") { PortalPlayer(mo).climbing = null; }

			Climbers.Delete(Climbers.Find(mo)); // ...and delete if from the climbers list.  
			Climbers.ShrinkToFit(); // Re-shrink the array
		}
	}

	override bool Used(Actor user)
	{
		if (user.player && user.pos.z <= pos.z + 16 && user.pos.z >= pos.z - ladderheight - user.height)
		{
			user.vel.z += user.speed / 2 * friction;
			user.player.usedown = false;

			return true;
		}
		else { return false; }
	}
}

class ClimbableZone : LadderBase
{
	Default
	{
		//$Category Portal/Ladders
		//$Title Climbable Zone
		Alpha 0.5;
		RenderStyle "Stencil";
		StencilColor "Orange";
	}

	override void PostBeginPlay()
	{
		bInvisible = True;

		ladderheight *= scale.y;

		Super.PostBeginPlay();
	}
}