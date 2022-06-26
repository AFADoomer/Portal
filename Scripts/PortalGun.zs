class PortalGun : Weapon
{
	PortalSpot portalA, portalB;
	bool dual, cleared, shottype, firing;
	
	PortalFindHitPointTracer portaltracer;

	Property Dual:dual;

	Default
	{
		//$Category Portal/Objects
		//$Title Portal Gun (Blue Only)
		+WEAPON.CHEATNOTWEAPON
		Weapon.SelectionOrder 1;
		Weapon.AmmoUse 0;
		Weapon.UpSound "portalgun/up";
		Weapon.ReadySound "";
		Inventory.AltHUDIcon "TNT1A0";
		Inventory.Pickupmessage "$PORTALGUNPICKUP";
		Inventory.PickupSound "";
		Tag "$PORTALGUNTAG";
		Weapon.BobSpeed 0.7;
		Weapon.BobStyle "Alpha";
	}

	States
	{
		Ready:
			PGUN A 0 { if (invoker.shottype) { return ResolveState("Ready.Alt"); } return ResolveState(null); }
			PGUN A 1 A_PortalWeaponReady;
			Loop;
		Ready.Alt:
			PGUN K 1 A_PortalWeaponReady;
			Loop;
		Deselect:
			PGUN A 0 { if (invoker.shottype) { return ResolveState("Deselect.Alt"); } return ResolveState(null); }
			PGUN A 1 A_Lower;
			Loop;
		Deselect.Alt:
			PGUN K 1 A_Lower;
			Loop;
		Select:
			PGUN A 0 { if (invoker.shottype) { return ResolveState("Select.Alt"); } return ResolveState(null); }
			PGUN A 1 A_Raise;
			Loop;
		Select.Alt:
			PGUN K 1 A_Raise;
			Loop;
		Fire:
			PGUN B 4 A_FirePortalGun;
			PGUN CDE 8 A_PortalWeaponReady();
			Goto Ready;
		AltFire:
			PGUN A 0 { if (!invoker.dual) { return ResolveState("Fire"); } return ResolveState(null); }
			PGUN L 4 A_FirePortalGun;
			PGUN MNO 8 A_PortalWeaponReady();
			Goto Ready;
 		Spawn:
			PGUN S -1;
			Stop;
		Shake:
			PGUN A 0 { if (invoker.shottype) { return ResolveState("Shake.Alt"); } return ResolveState(null); }
			PGUN F 5;
			PGUN GH 10;
			Goto Ready;
		Shake.Alt:
			PGUN P 5;
			PGUN QR 10;
			Goto Ready;
		Carry:
			PGUN A 0 { if (invoker.shottype) { return ResolveState("Carry.Alt"); } return ResolveState(null); }
			PGUN BC 4;
		Carry.Loop:
			PGUN C 8;
			Loop;
		Carry.Alt:
			PGUN LM 4;
		Carry.Alt.Loop:
			PGUN M 8;
			Loop;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER);
	}

	override void PostBeginPlay()
	{
		portaltracer = new("PortalFindHitPointTracer");

		bNoGravity = bStandStill;

		Super.PostBeginPlay();
	}

	action void A_PortalWeaponReady()
	{
		int flags = 0;

		if (player && player.mo && player.ReadyWeapon)
		{
			if ((player.cmd.buttons & BT_ATTACK || player.cmd.buttons & BT_ALTATTACK) && player.attackdown) { return; } // No automatic refire

			if (PortalPlayer(player.mo) && PortalPlayer(player.mo).DragTarget) { flags |= WRF_NOFIRE; }
/*
// No capability to define custom translations in ZScript, yet, and setting the actor's fill color has no effect
			color pri, alt;

			if (multiplayer)
			{
				pri = player.getColor();
				alt = color("FF FF FF") - pri;
			}
			else
			{
				pri = "00 7B FF";
				alt = "FF 84 00";
			}

			let psp = player.GetPSprite(PSP_WEAPON);
			if (psp)
			{
				if (psp.frame > 9) { player.ReadyWeapon.SetShade(alt); }
				else { player.ReadyWeapon.SetShade(pri); }
			}
*/
		}

		A_WeaponReady(flags);
	}

	state GetCarryState()
	{
		return FindState('Carry');
	}

	action void A_FirePortalGun()
	{
		if (player)
		{
			Weapon weap = player.ReadyWeapon;
			if (weap != null && invoker == weap && stateinfo != null && stateinfo.mStateType == STATE_Psprite)
			{
				if (!weap.DepleteAmmo(weap.bAltFire, true, 1)) { return; }
				player.SetPsprite(PSP_FLASH, weap.FindState('Flash'), true);
			}

			player.mo.PlayAttacking2();
		}

		if (invoker.dual && player.ReadyWeapon && player.ReadyWeapon.bAltFire) { A_StartSound("portalgun/fire2", CHAN_WEAPON); invoker.shottype = 1; }
		else { A_StartSound("portalgun/fire1", CHAN_WEAPON); invoker.shottype = 0; }

		DoTrace(self, angle, 2048, pitch, 0, player.viewheight, invoker.portaltracer);

		int type = invoker.portaltracer.Results.HitType;

		Actor portal = Spawn("PortalSpot", invoker.portaltracer.Results.HitPos);

		if (portal)
		{
			portal.master = self;
			portal.ChangeTID(9990 + PlayerNumber());

			Vector3 snappos = invoker.portaltracer.Results.HitPos;
			snappos.x = invoker.RoundToMultiple(snappos.x, 16.0);
			snappos.y = invoker.RoundToMultiple(snappos.y, 16.0);
			snappos.z = invoker.RoundToMultiple(snappos.z, 16.0);

			if (type == TRACE_HitWall)
			{
				Line linedef = invoker.portaltracer.Results.HitLine;
				double lineangle;

				if (!linedef.delta.x) { lineangle = 0; }
				else if (!linedef.delta.y) { lineangle = 90; }
				else { lineangle = (atan(linedef.delta.y / linedef.delta.x) + 270) % 360; }

				if (abs(deltaangle(lineangle, portal.AngleTo(self))) > 90) { lineangle += 180; }

				portal.angle = lineangle;

				portal.SetOrigin(portal.pos + AngleToVector(portal.AngleTo(self), 1), false); // Offset from the wall slightly to avoid z-fighting
				PortalSpot(portal).snappos = snappos + AngleToVector(portal.AngleTo(self), 1);
				PortalSpot(portal).shotpos = invoker.portaltracer.Results.HitPos + AngleToVector(portal.AngleTo(self), 1);
				PortalSpot(portal).linedef = linedef; // Save the linedef and angle for reference later (so portals can be destroyed if the surface moves)
				PortalSpot(portal).lineangle = lineangle;
			}
			else
			{
				portal.angle = portal.AngleTo(self);

				if (type == TRACE_HitFloor || type == TRACE_HitCeiling)
				{
					secplane splane;
					Vector3 normal;
					int zoffset;

					if (type == TRACE_HitFloor)
					{
						splane = invoker.portaltracer.Results.HitSector.floorplane;
						normal = splane.normal;
						zoffset = 2;
					}
					else if (type == TRACE_HitCeiling)
					{
						splane = invoker.portaltracer.Results.HitSector.ceilingplane;
						normal = splane.normal;
						zoffset = -2;
					}

					portal.pitch = -atan2(normal.z, normal.xy.length());

					PortalSpot(portal).slopeangle = atan2(normal.y, normal.x);
					if (portal.pitch % 90) { portal.angle = PortalSpot(portal).slopeangle; } // Automatically align portals on slopes to the slope direction

					portal.SetOrigin(portal.pos + (0, 0, zoffset), false);
					PortalSpot(portal).shotpos = invoker.portaltracer.Results.HitPos + (0, 0, zoffset);
					PortalSpot(portal).snappos = snappos;
				}
			}

			if (player && player.ReadyWeapon.bAltFire && invoker.dual)
			{
				invoker.PortalSetup(PortalSpot(portal), 1);
			}
			else
			{
				ThinkerIterator it = ThinkerIterator.Create("StaticPortalSpot", Thinker.STAT_USER + 1);
				PortalSpot mo;

				if (mo = PortalSpot(it.Next(true)))
				{
					PortalSpot(portal).pair = mo;

					invoker.PortalSetup(mo, 1, false);
				}

				invoker.PortalSetup(PortalSpot(portal), 0);
			}

			if (portal.waterlevel) { PortalSpot(portal).pair = PortalSpot(portal); }
		}
	}

	void PortalSetup(PortalSpot portal, int frame, bool destroyold = true)
	{
		portal.frame = frame;

		int index;
		if (owner) { index = owner.PlayerNumber() + 1; }

		portal.camtex = "PORTAL" .. index .. (frame ? "A" : "B");

		SpriteID spr = GetSpriteIndex("POR" .. index);
		if (spr) { portal.sprite = spr; }

		if (portal.pair) { PortalSpot(portal.pair).pair = portal; }
	}

	double RoundToMultiple(double i, double n)
	{
		return (i % n) > (n / 2) ? i + n - (i % n) : i - (i % n);
	}

	action void DoTrace(Actor origin, double angle, double dist, double pitch, int flags, double zoffset, PortalFindHitPointTracer thistracer)
	{
		if (!origin) { origin = self; }

		thistracer.skipspecies = origin.species;
		thistracer.skipactor = origin;

		Vector3 tracedir = (cos(angle) * cos(pitch), sin(angle) * cos(pitch), -sin(pitch));
		thistracer.Trace(origin.pos + (0, 0, zoffset), origin.CurSector, tracedir, dist, 0);
	}
}

class DualPortalGun : PortalGun
{
	Default
	{
		//$Title Portal Gun
		-WEAPON.CHEATNOTWEAPON // Give this one by default with cheat (works in all cases, even with static portals)
		Inventory.Pickupmessage "$PORTALGUNPICKUP2";
		Tag "$PORTALGUNTAG2";
		PortalGun.Dual true;
	}
}