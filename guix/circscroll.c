/* SPDX-License-Identifier: MIT
 *
 * circscroll -- circular scrolling for a round touchpad, for any compositor.
 *
 * Made for the round touchpad of the Panasonic CF-SZ5 ("SynPS/2 Synaptics
 * TouchPad"). libinput (Hyprland, sway, GNOME...) has no circular scrolling
 * for it, so this program does it before libinput sees the events:
 *
 *  - It takes the real touchpad for itself (EVIOCGRAB) and makes a virtual
 *    copy of it (uinput). Hyprland uses the copy as a normal touchpad.
 *  - A touch that starts on the outer ring of the pad is held back for a
 *    moment. If the finger moves around the ring, the touch is used for
 *    scrolling, and the copy does not see it. If the finger moves inward,
 *    or lifts quickly (a tap), the held-back events go to the copy, so the
 *    pointer and tap-to-click work as before.
 *  - Scrolling goes out through a second virtual device, a scroll wheel.
 *    Clockwise scrolls down.
 *
 * The ring is the area outside the ellipse inside the four edges (the same
 * rule as the Synaptics X11 driver: LeftEdge, RightEdge, TopEdge,
 * BottomEdge). The defaults are the values that worked on Debian.
 *
 * If this program stops, the kernel ends the grab, and the real touchpad
 * works as before (without circular scrolling).
 *
 * Build:
 *   gcc -O2 -Wall -o circscroll circscroll.c \
 *       $(pkg-config --cflags --libs libevdev) -lm
 * Find good edges: stop the service, then run "circscroll --print" and
 * touch the rim of the pad.
 */

#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <limits.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <libevdev/libevdev.h>
#include <libevdev/libevdev-uinput.h>

#define VERSION "0.1"

/* ------------------------------------------------------------------ */
/* Options                                                             */

static struct {
	const char *device;  /* name, or a path such as /dev/input/event5 */
	double left, right, top, bottom;
	double delta;        /* radians of finger movement per wheel step */
	int reverse;         /* 1 = clockwise scrolls up */
	int tap_ms;          /* a ring touch shorter than this can be a tap */
	double decide;       /* movement before deciding (ring radius = 1) */
	int verbose;
	int print;           /* only print touches, to find the edges */
} opt = {
	.device = "SynPS/2 Synaptics TouchPad",
	.left = 1770, .right = 5220, .top = 1670, .bottom = 4260,
	.delta = 0.1,
	.reverse = 0,
	.tap_ms = 180,
	.decide = 0.06,
	.verbose = 0,
	.print = 0,
};

static void logmsg(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	fputc('\n', stderr);
	fflush(stderr);
}

#define VLOG(...) do { if (opt.verbose) logmsg(__VA_ARGS__); } while (0)

/* ------------------------------------------------------------------ */
/* Geometry                                                            */

static double cx, cy, rx, ry;  /* center and half sizes of the ellipse */

static void norm(int x, int y, double *nx, double *ny)
{
	*nx = (x - cx) / rx;
	*ny = (y - cy) / ry;
}

/* 1 if the point is outside the ellipse (on the ring). */
static int in_ring(int x, int y)
{
	double nx, ny;
	norm(x, y, &nx, &ny);
	return nx * nx + ny * ny > 1.0;
}

/* Angle in the normal math direction: counterclockwise is positive.
 * The y axis of the touchpad points down, so it is turned around. */
static double angle_of(int x, int y)
{
	double nx, ny;
	norm(x, y, &nx, &ny);
	return atan2(-ny, nx);
}

/* Smallest difference a2 - a1, in (-pi, pi]. */
static double angle_diff(double a1, double a2)
{
	double d = fmod(a2 - a1, 2 * M_PI);
	if (d < 0)
		d += 2 * M_PI;
	if (d > M_PI)
		d -= 2 * M_PI;
	return d;
}

/* ------------------------------------------------------------------ */
/* Devices                                                             */

static struct libevdev *dev;           /* the real touchpad */
static struct libevdev_uinput *pad;    /* the virtual copy */
static struct libevdev_uinput *wheel;  /* the virtual scroll wheel */
static volatile sig_atomic_t stop;

static void on_signal(int sig)
{
	(void)sig;
	stop = 1;
}

/* 1 if /dev/input/eventN is a virtual (uinput) device, for example our
 * own copy of the touchpad. */
static int is_virtual(const char *event_name)
{
	char link[300], target[PATH_MAX];
	snprintf(link, sizeof link, "/sys/class/input/%s/device", event_name);
	if (!realpath(link, target))
		return 0;
	return strstr(target, "/virtual/") != NULL;
}

/* Open the device with this path or name. Returns an fd, or -1. */
static int open_device(const char *want)
{
	if (want[0] == '/')
		return open(want, O_RDONLY | O_NONBLOCK | O_CLOEXEC);

	DIR *d = opendir("/dev/input");
	if (!d)
		return -1;
	struct dirent *e;
	int found = -1;
	while (found < 0 && (e = readdir(d))) {
		if (strncmp(e->d_name, "event", 5) != 0 || is_virtual(e->d_name))
			continue;
		char path[300];
		snprintf(path, sizeof path, "/dev/input/%s", e->d_name);
		int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
		if (fd < 0)
			continue;
		char name[256] = "";
		if (ioctl(fd, EVIOCGNAME(sizeof name - 1), name) >= 0 &&
		    strcmp(name, want) == 0) {
			found = fd;
			logmsg("circscroll: found \"%s\" at %s", want, path);
		} else {
			close(fd);
		}
	}
	closedir(d);
	return found;
}

static int val(unsigned int type, unsigned int code)
{
	return libevdev_get_event_value(dev, type, code);
}

/* Number of fingers on the pad now. */
static int finger_count(void)
{
	if (val(EV_KEY, BTN_TOOL_QUINTTAP)) return 5;
	if (val(EV_KEY, BTN_TOOL_QUADTAP)) return 4;
	if (val(EV_KEY, BTN_TOOL_TRIPLETAP)) return 3;
	if (val(EV_KEY, BTN_TOOL_DOUBLETAP)) return 2;
	int n = val(EV_KEY, BTN_TOOL_FINGER) ? 1 : 0;
	if (libevdev_has_event_code(dev, EV_ABS, ABS_MT_TRACKING_ID)) {
		int m = 0, slots = libevdev_get_num_slots(dev);
		for (int s = 0; s < slots; s++)
			if (libevdev_get_slot_value(dev, s, ABS_MT_TRACKING_ID) >= 0)
				m++;
		if (m > n)
			n = m;
	}
	return n;
}

/* A finger is on the pad (or near it, for pads that report hovering). */
static int contact(void)
{
	return val(EV_KEY, BTN_TOUCH) || finger_count() > 0;
}

/* ------------------------------------------------------------------ */
/* Event buffers                                                       */

struct ev {
	unsigned short type, code;
	int value;
	int slot;        /* the MT slot in effect for this event */
	long long usec;  /* time stamp */
};

struct evbuf {
	struct ev *e;
	size_t n, cap;
};

static void buf_add(struct evbuf *b, const struct ev *e)
{
	if (b->n == b->cap) {
		b->cap = b->cap ? b->cap * 2 : 256;
		b->e = realloc(b->e, b->cap * sizeof *b->e);
		if (!b->e) {
			logmsg("circscroll: out of memory");
			exit(1);
		}
	}
	b->e[b->n++] = *e;
}

static struct evbuf frame;    /* events of the frame that is being read */
static struct evbuf pending;  /* held-back frames of a ring touch */
#define PENDING_MAX 20000     /* about 30 seconds of a resting finger */

/* ------------------------------------------------------------------ */
/* Writing to the virtual touchpad                                     */

static int virt_slot = -1;    /* the slot that the copy is in now */

static int is_mt_code(unsigned int code)
{
	return code >= ABS_MT_TOUCH_MAJOR && code <= ABS_MT_TOOL_Y;
}

static void pad_write(unsigned int type, unsigned int code, int value)
{
	int rc = libevdev_uinput_write_event(pad, type, code, value);
	if (rc < 0)
		logmsg("circscroll: write to virtual touchpad failed: %s",
		       strerror(-rc));
}

/* Send one event to the copy. The copy must be in the same MT slot as the
 * real pad was when the event happened. Held-back events can change the
 * slot of the real pad, so send an ABS_MT_SLOT first when needed. */
static void forward(const struct ev *e)
{
	if (e->type == EV_ABS && e->code == ABS_MT_SLOT) {
		pad_write(EV_ABS, ABS_MT_SLOT, e->value);
		virt_slot = e->value;
		return;
	}
	if (e->type == EV_ABS && is_mt_code(e->code) && e->slot >= 0 &&
	    e->slot != virt_slot) {
		pad_write(EV_ABS, ABS_MT_SLOT, e->slot);
		virt_slot = e->slot;
	}
	pad_write(e->type, e->code, e->value);
}

static void forward_all(const struct evbuf *b)
{
	for (size_t i = 0; i < b->n; i++)
		forward(&b->e[i]);
}

/* Make the copy show the same state as the real pad. Use this after
 * events were dropped. The kernel ignores values that do not change. */
static void resync(void)
{
	if (libevdev_has_event_code(dev, EV_ABS, ABS_MT_SLOT)) {
		int slots = libevdev_get_num_slots(dev);
		for (int s = 0; s < slots; s++) {
			pad_write(EV_ABS, ABS_MT_SLOT, s);
			for (unsigned int c = ABS_MT_TOUCH_MAJOR; c <= ABS_MT_TOOL_Y; c++)
				if (libevdev_has_event_code(dev, EV_ABS, c))
					pad_write(EV_ABS, c, libevdev_get_slot_value(dev, s, c));
		}
		virt_slot = libevdev_get_current_slot(dev);
		pad_write(EV_ABS, ABS_MT_SLOT, virt_slot);
	}
	for (unsigned int c = 0; c < ABS_MT_SLOT; c++)
		if (libevdev_has_event_code(dev, EV_ABS, c))
			pad_write(EV_ABS, c, val(EV_ABS, c));
	for (unsigned int c = 0; c <= KEY_MAX; c++)
		if (libevdev_has_event_code(dev, EV_KEY, c))
			pad_write(EV_KEY, c, val(EV_KEY, c));
	pad_write(EV_SYN, SYN_REPORT, 0);
	VLOG("circscroll: resync");
}

/* ------------------------------------------------------------------ */
/* Scrolling                                                           */

static double last_angle;
static int angle_lost;     /* finger was near the center */
static double hires_rest;  /* part of a hi-res unit not sent yet */
static int hires_sum;      /* hi-res units since the last full step */

static void scroll_reset(int x, int y)
{
	last_angle = angle_of(x, y);
	angle_lost = 0;
	hires_rest = 0;
	hires_sum = 0;
}

static void scroll_update(int x, int y)
{
	double nx, ny;
	norm(x, y, &nx, &ny);
	if (nx * nx + ny * ny < 0.3 * 0.3) {
		/* Near the center the angle jumps. Wait until the finger
		 * is out again. */
		angle_lost = 1;
		return;
	}
	double a = angle_of(x, y);
	if (angle_lost) {
		last_angle = a;
		angle_lost = 0;
		return;
	}
	double d = angle_diff(last_angle, a);  /* > 0: counterclockwise */
	last_angle = a;

	/* Wheel: positive = up. Clockwise (d < 0) scrolls down.
	 * 120 hi-res units = one wheel step. */
	double v = d / opt.delta * 120.0;
	if (opt.reverse)
		v = -v;
	v += hires_rest;
	int hires = (int)v;  /* toward zero */
	hires_rest = v - hires;
	if (hires == 0)
		return;

	hires_sum += hires;
	int steps = hires_sum / 120;
	hires_sum -= steps * 120;

	libevdev_uinput_write_event(wheel, EV_REL, REL_WHEEL_HI_RES, hires);
	if (steps)
		libevdev_uinput_write_event(wheel, EV_REL, REL_WHEEL, steps);
	libevdev_uinput_write_event(wheel, EV_SYN, SYN_REPORT, 0);
}

/* ------------------------------------------------------------------ */
/* The state machine, run once per frame (at each SYN_REPORT)          */

enum state {
	IDLE,     /* no finger */
	ACTIVE,   /* a normal touch: everything goes to the copy */
	PENDING,  /* a touch started on the ring: held back */
	SCROLL,   /* a ring touch that scrolls: the copy sees nothing */
};

static const char *state_name[] = { "idle", "active", "pending", "scroll" };
static enum state state = IDLE;
static int had_contact;
static int start_x, start_y;
static long long start_usec;

static void set_state(enum state s)
{
	if (s != state)
		VLOG("circscroll: %s -> %s", state_name[state], state_name[s]);
	state = s;
}

static int frame_has_button(void)
{
	for (size_t i = 0; i < frame.n; i++) {
		const struct ev *e = &frame.e[i];
		if (e->type == EV_KEY &&
		    (e->code == BTN_LEFT || e->code == BTN_RIGHT ||
		     e->code == BTN_MIDDLE))
			return 1;
	}
	return 0;
}

/* Send only the button events of this frame (the touch is not shown). */
static void forward_buttons(void)
{
	int any = 0;
	for (size_t i = 0; i < frame.n; i++) {
		const struct ev *e = &frame.e[i];
		if (e->type == EV_KEY &&
		    (e->code == BTN_LEFT || e->code == BTN_RIGHT ||
		     e->code == BTN_MIDDLE)) {
			pad_write(e->type, e->code, e->value);
			any = 1;
		}
	}
	if (any)
		pad_write(EV_SYN, SYN_REPORT, 0);
}

static void print_frame(void)
{
	int c = contact();
	int x = val(EV_ABS, ABS_X), y = val(EV_ABS, ABS_Y);
	if (c && !had_contact)
		printf("touch  x=%d y=%d %s\n", x, y, in_ring(x, y) ? "RING" : "inside");
	else if (!c && had_contact)
		printf("lift   x=%d y=%d\n", x, y);
	fflush(stdout);
	had_contact = c;
}

static void handle_frame(long long usec)
{
	int c = contact();
	int fingers = finger_count();
	int x = val(EV_ABS, ABS_X), y = val(EV_ABS, ABS_Y);
	int button = frame_has_button();

	switch (state) {
	case IDLE:
		if (c && !had_contact && fingers <= 1 && !button && in_ring(x, y)) {
			pending.n = 0;
			for (size_t i = 0; i < frame.n; i++)
				buf_add(&pending, &frame.e[i]);
			start_x = x;
			start_y = y;
			start_usec = usec;
			set_state(PENDING);
		} else {
			forward_all(&frame);
			if (c)
				set_state(ACTIVE);
		}
		break;

	case ACTIVE:
		forward_all(&frame);
		if (!c)
			set_state(IDLE);
		break;

	case PENDING:
		for (size_t i = 0; i < frame.n; i++)
			buf_add(&pending, &frame.e[i]);
		if (!c) {
			if (usec - start_usec <= (long long)opt.tap_ms * 1000) {
				VLOG("circscroll: short ring touch: passed on (tap)");
				forward_all(&pending);
			} else {
				VLOG("circscroll: long ring touch without movement: dropped");
				resync();
			}
			pending.n = 0;
			set_state(IDLE);
		} else if (fingers > 1 || button || pending.n > PENDING_MAX) {
			forward_all(&pending);
			pending.n = 0;
			set_state(ACTIVE);
		} else {
			double sx, sy, nx, ny;
			norm(start_x, start_y, &sx, &sy);
			norm(x, y, &nx, &ny);
			double dx = nx - sx, dy = ny - sy;
			if (hypot(dx, dy) >= opt.decide) {
				/* Split the movement into a part toward the
				 * center and a part around the ring. */
				double len = hypot(sx, sy);
				double ux = sx / len, uy = sy / len;
				double radial = dx * ux + dy * uy;
				double around = fabs(dx * uy - dy * ux);
				if (radial < 0 && -radial > around) {
					VLOG("circscroll: ring touch moves inward: pointer");
					forward_all(&pending);
					pending.n = 0;
					set_state(ACTIVE);
				} else {
					pending.n = 0;
					scroll_reset(start_x, start_y);
					scroll_update(x, y);
					set_state(SCROLL);
				}
			}
		}
		break;

	case SCROLL:
		if (button)
			forward_buttons();
		if (c) {
			scroll_update(x, y);
		} else {
			resync();
			set_state(IDLE);
		}
		break;
	}
	had_contact = c;
}

/* ------------------------------------------------------------------ */
/* Setup                                                               */

static void usage(FILE *f)
{
	fprintf(f,
"Usage: circscroll [OPTION]...\n"
"Circular scrolling on a round touchpad: move one finger around the rim.\n"
"\n"
"  -d, --device=NAME|PATH  touchpad name or /dev/input/eventN\n"
"                          (default: \"SynPS/2 Synaptics TouchPad\")\n"
"  -e, --edges=L,R,T,B     edges of the inner area (default: 1770,5220,1670,4260)\n"
"                          The ring is the area outside the ellipse inside them.\n"
"  -s, --step=RADIANS      finger movement per wheel step (default: 0.1)\n"
"                          Larger = slower scrolling.\n"
"  -r, --reverse           clockwise scrolls up\n"
"      --tap-ms=MS         a ring touch shorter than this is a tap (default: 180)\n"
"      --decide=FRACTION   movement before a ring touch is decided (default: 0.06)\n"
"  -p, --print             do not scroll; only print where touches start and end\n"
"                          (stop the service first)\n"
"  -v, --verbose           print what happens\n"
"  -h, --help              show this text\n"
"      --version           show the version\n");
}

static void parse_args(int argc, char **argv)
{
	static const struct option longopts[] = {
		{ "device",  required_argument, 0, 'd' },
		{ "edges",   required_argument, 0, 'e' },
		{ "step",    required_argument, 0, 's' },
		{ "reverse", no_argument,       0, 'r' },
		{ "tap-ms",  required_argument, 0, 'T' },
		{ "decide",  required_argument, 0, 'D' },
		{ "print",   no_argument,       0, 'p' },
		{ "verbose", no_argument,       0, 'v' },
		{ "help",    no_argument,       0, 'h' },
		{ "version", no_argument,       0, 'V' },
		{ 0, 0, 0, 0 }
	};
	int o;
	while ((o = getopt_long(argc, argv, "d:e:s:rpvh", longopts, NULL)) != -1) {
		switch (o) {
		case 'd': opt.device = optarg; break;
		case 'e':
			if (sscanf(optarg, "%lf,%lf,%lf,%lf", &opt.left, &opt.right,
			           &opt.top, &opt.bottom) != 4 ||
			    opt.right <= opt.left || opt.bottom <= opt.top) {
				fprintf(stderr, "circscroll: --edges needs L,R,T,B with L<R and T<B\n");
				exit(2);
			}
			break;
		case 's':
			opt.delta = atof(optarg);
			if (opt.delta < 0.005) {
				fprintf(stderr, "circscroll: --step must be 0.005 or more\n");
				exit(2);
			}
			break;
		case 'r': opt.reverse = 1; break;
		case 'T': opt.tap_ms = atoi(optarg); break;
		case 'D': opt.decide = atof(optarg); break;
		case 'p': opt.print = 1; break;
		case 'v': opt.verbose = 1; break;
		case 'h': usage(stdout); exit(0);
		case 'V': printf("circscroll %s\n", VERSION); exit(0);
		default: usage(stderr); exit(2);
		}
	}
	cx = (opt.left + opt.right) / 2;
	cy = (opt.top + opt.bottom) / 2;
	rx = (opt.right - opt.left) / 2;
	ry = (opt.bottom - opt.top) / 2;
}

static struct libevdev_uinput *make_wheel(void)
{
	struct libevdev *w = libevdev_new();
	libevdev_set_name(w, "circscroll wheel");
	libevdev_set_id_bustype(w, BUS_VIRTUAL);
	libevdev_set_id_vendor(w, 0x1209);
	libevdev_set_id_product(w, 0x0c5c);
	libevdev_enable_event_type(w, EV_REL);
	libevdev_enable_event_code(w, EV_REL, REL_X, NULL);
	libevdev_enable_event_code(w, EV_REL, REL_Y, NULL);
	libevdev_enable_event_code(w, EV_REL, REL_WHEEL, NULL);
	libevdev_enable_event_code(w, EV_REL, REL_WHEEL_HI_RES, NULL);
	libevdev_enable_event_type(w, EV_KEY);
	libevdev_enable_event_code(w, EV_KEY, BTN_LEFT, NULL);
	libevdev_enable_event_code(w, EV_KEY, BTN_RIGHT, NULL);
	libevdev_enable_event_code(w, EV_KEY, BTN_MIDDLE, NULL);
	struct libevdev_uinput *u = NULL;
	int rc = libevdev_uinput_create_from_device(w, LIBEVDEV_UINPUT_OPEN_MANAGED, &u);
	libevdev_free(w);
	if (rc < 0) {
		logmsg("circscroll: cannot make the virtual wheel: %s", strerror(-rc));
		return NULL;
	}
	return u;
}

int main(int argc, char **argv)
{
	parse_args(argc, argv);

	struct sigaction sa = { .sa_handler = on_signal };  /* no SA_RESTART */
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGHUP, &sa, NULL);

	/* At boot the touchpad (and /dev/uinput) can appear a little later
	 * than this service. Wait up to 60 seconds. */
	int fd = -1;
	for (int i = 0; i < 60 && !stop; i++) {
		fd = open_device(opt.device);
		if (fd >= 0)
			break;
		if (i == 0)
			logmsg("circscroll: waiting for \"%s\"...", opt.device);
		sleep(1);
	}
	if (fd < 0) {
		logmsg("circscroll: touchpad \"%s\" not found", opt.device);
		return 1;
	}

	int rc = libevdev_new_from_fd(fd, &dev);
	if (rc < 0) {
		logmsg("circscroll: cannot read the touchpad: %s", strerror(-rc));
		return 1;
	}
	if (!libevdev_has_event_code(dev, EV_ABS, ABS_X) ||
	    !libevdev_has_event_code(dev, EV_ABS, ABS_Y)) {
		logmsg("circscroll: \"%s\" has no ABS_X/ABS_Y; not a touchpad",
		       libevdev_get_name(dev));
		return 1;
	}

	const struct input_absinfo *ax = libevdev_get_abs_info(dev, ABS_X);
	const struct input_absinfo *ay = libevdev_get_abs_info(dev, ABS_Y);
	logmsg("circscroll %s: x %d..%d, y %d..%d; ring outside ellipse in "
	       "x %.0f..%.0f, y %.0f..%.0f; %.3f rad per step%s",
	       VERSION, ax->minimum, ax->maximum, ay->minimum, ay->maximum,
	       opt.left, opt.right, opt.top, opt.bottom, opt.delta,
	       opt.reverse ? ", reversed" : "");

	if (!opt.print) {
		rc = libevdev_grab(dev, LIBEVDEV_GRAB);
		if (rc < 0) {
			logmsg("circscroll: cannot grab the touchpad: %s "
			       "(is circscroll already running?)", strerror(-rc));
			return 1;
		}
		/* The kernel already filtered the real values ("fuzz").
		 * The copy must not filter them a second time. */
		for (unsigned int c = 0; c <= ABS_MAX; c++)
			if (libevdev_has_event_code(dev, EV_ABS, c))
				libevdev_set_abs_fuzz(dev, c, 0);

		for (int i = 0; i < 30 && !stop; i++) {
			rc = libevdev_uinput_create_from_device(dev,
				LIBEVDEV_UINPUT_OPEN_MANAGED, &pad);
			if (rc >= 0)
				break;
			if (i == 0)
				logmsg("circscroll: waiting for /dev/uinput (%s)...",
				       strerror(-rc));
			sleep(1);
		}
		if (!pad) {
			logmsg("circscroll: cannot make the virtual touchpad: %s",
			       strerror(-rc));
			return 1;
		}
		wheel = make_wheel();
		if (!wheel)
			return 1;
		logmsg("circscroll: virtual touchpad %s, wheel %s",
		       libevdev_uinput_get_devnode(pad),
		       libevdev_uinput_get_devnode(wheel));
	}

	/* The fd stays non-blocking: after dropped events, libevdev reads the
	 * rest of the kernel queue, and that read must not wait. poll() waits
	 * for new events. */
	struct pollfd pfd = { .fd = fd, .events = POLLIN };
	unsigned int flags = LIBEVDEV_READ_FLAG_NORMAL;
	while (!stop) {
		struct input_event ie;
		rc = libevdev_next_event(dev, flags, &ie);
		if (rc == LIBEVDEV_READ_STATUS_SYNC) {
			/* The kernel dropped events. libevdev now sends the
			 * changes that bring us up to date; they end with a
			 * SYN_REPORT like a normal frame. */
			if (flags & LIBEVDEV_READ_FLAG_SYNC) {
				/* one of those changes: handle it below */
			} else {
				VLOG("circscroll: events dropped by the kernel");
				frame.n = 0;
				flags = LIBEVDEV_READ_FLAG_SYNC;
				continue;
			}
		} else if (rc == -EAGAIN) {
			if (flags & LIBEVDEV_READ_FLAG_SYNC) {
				/* End of the sync changes. Events from before
				 * the drop may not have reached the copy, so
				 * bring the copy up to date too, unless it must
				 * not see the current touch. */
				flags = LIBEVDEV_READ_FLAG_NORMAL;
				if (!opt.print && (state == IDLE || state == ACTIVE))
					resync();
				continue;
			}
			/* No events now: wait. A signal ends the wait. */
			if (poll(&pfd, 1, -1) < 0 && errno != EINTR) {
				logmsg("circscroll: poll: %s", strerror(errno));
				rc = -errno;
				break;
			}
			continue;
		} else if (rc == -EINTR) {
			continue;
		} else if (rc < 0) {
			logmsg("circscroll: read error: %s", strerror(-rc));
			break;
		}

		struct ev e = {
			.type = ie.type, .code = ie.code, .value = ie.value,
			.slot = libevdev_has_event_code(dev, EV_ABS, ABS_MT_SLOT)
				? libevdev_get_current_slot(dev) : -1,
			.usec = (long long)ie.input_event_sec * 1000000 + ie.input_event_usec,
		};
		buf_add(&frame, &e);

		if (ie.type == EV_SYN && ie.code == SYN_REPORT) {
			if (opt.print)
				print_frame();
			else
				handle_frame(e.usec);
			frame.n = 0;
		}
	}

	if (!opt.print) {
		libevdev_grab(dev, LIBEVDEV_UNGRAB);
		libevdev_uinput_destroy(pad);
		libevdev_uinput_destroy(wheel);
	}
	libevdev_free(dev);
	close(fd);
	logmsg("circscroll: stopped");
	return stop ? 0 : 1;  /* 1: stopped by an error, for example the
	                       * touchpad went away (Shepherd restarts us) */
}
