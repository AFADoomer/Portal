class PortalStatusBar : BaseStatusBar
{
	override void Init()
	{
		Super.Init();
		SetSize(0, 320, 200);
		CompleteBorder = True;
	}

	override void Draw(int state, double TicFrac)
	{
		Super.Draw(state, TicFrac);

		if (!automapactive && screenblocks != 12)
		{
			DrawCrosshairHint();
		}
	}

	void DrawCrosshairHint()
	{
		if (!CPlayer) { return; }

		CVar debughealth = CVar.FindCVar("g_debughealth");

		if (debughealth && debughealth.GetBool() == True)
		{
			Screen.DrawText(SmallFont, 0, Screen.GetWidth() - 40, 10, String.Format("%i%%", CPlayer.health));
		}

		TextureID CrosshairImage;
		PortalGun gun;
		color pri = "00 7B FF";
		color alt = "FF 84 00";

		gun = PortalGun(CPlayer.ReadyWeapon);

		if (
			!gun ||
			!crosshair || 
			CPlayer.cheats & CF_CHASECAM ||
			gamestate == GS_TITLELEVEL || 
			CPlayer.health <= 0
		) { return; }


		if (multiplayer)
		{
			pri = CPlayer.getColor();
			alt = color("FF FF FF") - pri;
		}

		DrawCrosshair("PortalA" .. (gun.portalA ? "1" : "0"), pri);
		DrawCrosshair("PortalB" .. (gun.portalB ? "1" : "0"), alt);
	}

	void DrawCrosshair(String texture, color clr)
	{
		double maxwidth = int(screen.GetWidth() * crosshairscale / 8);

		TextureID icon = TexMan.CheckForTexture(texture, TexMan.Type_Any);

		if (icon)
		{
			Vector2 dimensions = TexMan.GetScaledSize(icon);

			// Force everything to maxwidth pixels at widest dimension
			if (dimensions.x > dimensions.y)
			{
				dimensions.y *= maxwidth / dimensions.x;
				dimensions.x = maxwidth;
			}
			else
			{
				dimensions.x *= maxwidth / dimensions.y;
				dimensions.y = maxwidth;
			}

			// Draw centered on screen, with offsets forced to center of the icon
			screen.DrawTexture (icon, false, screen.GetWidth() / 2, screen.GetHeight() / 2, DTA_DestWidthF, dimensions.x, DTA_DestHeightF, dimensions.y, DTA_AlphaChannel, true, DTA_FillColor, clr & 0xFFFFFF, DTA_CenterOffset, true);
		}
	}
}