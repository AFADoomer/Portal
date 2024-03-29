/*
   Coordinate Utility helper class.
   (C)2018 Marisa Kirisame, UnSX Team.
   Released under the GNU Lesser General Public License version 3 (or later).
   See https://www.gnu.org/licenses/lgpl-3.0.txt for its terms.
*/

Class PortalCoordUtil
{
	// projects a world point onto screen
	// view matrix setup mostly pulled from gutawer's code
	static Vector3 WorldToScreen( Vector3 vect, Vector3 eye, double pitch, double yaw, double roll, double vfov )
	{
		double ar = Screen.getWidth()/double(Screen.getHeight());
		double fovr = (ar>=1.3)?1.333333:ar;
		double fov = 2*atan(tan(clamp(vfov,5,170)*0.5)/fovr);
		float pr = level.pixelstretch;
		double angx = cos(pitch);
		double angy = sin(pitch)*pr;
		double alen = sqrt(angx*angx+angy*angy);
		double apitch = asin(angy/alen);
		double ayaw = yaw-90;
		// rotations
		PortalMatrix4 mRoll = PortalMatrix4.rotate((0,0,1),roll);
		PortalMatrix4 mPitch = PortalMatrix4.rotate((1,0,0),apitch);
		PortalMatrix4 mYaw = PortalMatrix4.rotate((0,-1,0),ayaw);
		// scaling
		PortalMatrix4 mScale = PortalMatrix4.identity();
		mScale.set(1,1,pr);
		// YZ swap
		PortalMatrix4 mYZ = PortalMatrix4.create();
		mYZ.set(0,0,1);
		mYZ.set(2,1,1);
		mYZ.set(1,2,-1);
		mYZ.set(3,3,1);
		// translation
		PortalMatrix4 mMove = PortalMatrix4.identity();
		mMove.set(3,0,-eye.x);
		mMove.set(3,1,-eye.y);
		mMove.set(3,2,-eye.z);
		// perspective
		PortalMatrix4 mPerspective = PortalMatrix4.perspective(fov,ar,5,65535);
		// full matrix
		PortalMatrix4 mView = mRoll.mul(mPitch);
		mView = mView.mul(mYaw);
		mView = mView.mul(mScale);
		mView = mView.mul(mYZ);
		mView = mView.mul(mMove);
		PortalMatrix4 mWorldToScreen = mPerspective.mul(mView);
		return mWorldToScreen.vmat(vect);
	}

	// converts a projected screen position to 2D canvas coords
	// thanks once again to gutawer for making this thing screenblocks-aware
	// [NEW] added second return value: true if the point has valid depth (i.e.: it's not behind view)
	// [TODO] handle forced aspect ratio (e.g.: 320x200 scaling)
	static Vector2, bool ToViewport( Vector3 screenpos, bool scrblocks = true )
	{
		if ( scrblocks )
		{
			int winx, winy, winw, winh;
			[winx,winy,winw,winh] = Screen.getViewWindow();
			int sh = Screen.getHeight();
			int ht = sh;
			int screenblocks = CVar.GetCVar("screenblocks",players[consoleplayer]).getInt();
			if ( screenblocks < 10 ) ht = (screenblocks*sh/10)&~7;
			int bt = sh-(ht+winy-((ht-winh)/2));
			return (winx,sh-bt-ht)+((screenpos.x+1)*winw,(-screenpos.y+1)*ht)*0.5, (screenpos.z<=1.0);
		}
		else return ((screenpos.x+1)*Screen.getWidth(),(-screenpos.y+1)*Screen.getHeight())*0.5, (screenpos.z<=1.0);
	}
}