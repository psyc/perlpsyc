# cvs messes up the perms
#
upd8:
	cvs -q update -dP
	chmod -R +r .
