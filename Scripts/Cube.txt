class Cube : CarryActor
{
	Default
	{
		//$Category Portal/Cubes
		//$Sprite "UNKNB0"
		-NODAMAGE
		Health 100;
		Height 22;
		Radius 14;
		Mass 55;
		BounceSound "cube/bounce";
		WallBounceSound "cube/bounce";
		CarryActor.Fizzle True;
		CarryActor.SlideSound "cube/slide";
	}

	States
	{
		Spawn:
			UNKN # -1;
			Stop;
		Death:
			Goto Fizzle;
	}

	override void BeginPlay()
	{
		ChangeStatNum(Thinker.STAT_USER); // Used to set actors that can activate buttons.
		Super.BeginPlay();
	}
}

class LaserCube : Cube
{
	Actor lasersource, interior;
	bool laserhit;

	Default
	{
		//$Title Laser Cube
	}

	override void PostBeginPlay()
	{
		while (!interior) { interior = Spawn("LaserCubeInterior", pos); }
		while (!lasersource) { lasersource = Spawn("LaserSpot", pos); }

		interior.master = self;

		Super.PostBeginPlay();
	}

	override void Tick()
	{
		if (lasersource)
		{
			lasersource.master = self;
//			lasersource.SetOrigin(pos + (radius * 1.4 * cos(angle), radius * 1.4 * sin(angle), height * 0.5), true);
			lasersource.SetOrigin(pos + (0, 0, height / 2), false);
			lasersource.angle = angle;

			if (laserhit)
			{
				lasersource.SetStateLabel("Active");
				A_AttachLight("LaserLight", DynamicLight.PointLight, 0xDD0000, int(radius), int(radius), DynamicLight.LF_ATTENUATE, (0, 0, height / 2));
				if (interior.alpha < 0.7) { interior.alpha = min(0.7, interior.alpha + 0.05); }
			}
			else
			{
				lasersource.SetStateLabel("Inactive");
				A_RemoveLight("LaserLight");
				if (interior.alpha > 0.35) { interior.alpha = max(0.35, interior.alpha - 0.05); }
			}
		}

		laserhit = false;

		Super.Tick();
	}	

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (inflictor is "LaserBeam" && source != self)
		{
			laserhit = true;
		}

		return 0;
	}
}

class LaserCubeInterior : Actor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		Renderstyle "Translucent";
		Alpha 0.7;
		Species "Laser";
	}

	override void Tick()
	{
		if (LaserCube(master))
		{
			angle = master.angle;
			pitch = master.pitch;
			roll = master.roll;
			SetXYZ(master.pos - (0, 0, LaserCube(master).zoffset));
			return;
		}
		else { Destroy(); }

		Super.Tick();
	}

	States
	{
		Spawn:
			UNKN A -1;
			Stop;
	}
}