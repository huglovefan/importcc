// test that __builtin_dump() works

typedef enum Bb { bb=2, } Bbb;

struct A
{
	int x, y;
	enum Bb asdasd;
	enum Aa : Bbb { aa=1, } e;
	int ints[3];
	char *str;
	void *np;
	void(*fp)(void);
	float flt;
	double dbl;
	long double longdbl;
	char ca, cb;
	void *one;
	union U {
		int x;
		struct A *ap, ***appp;
		float y;
		void *xyz;
		int abc[123];
		struct { int x; } other;
	} uu;
	const char *conststr;
	struct { int hello; } inner;
	unsigned int bits : 2;
	_Bool c11bool;
};

void dummy(){}

struct A a = {
	123, 456,
	bb,
	aa,
	{ 5, 4, 3 },
	"hello",
	0,
	dummy,
	12.34,
	56.78,
	910.1112,
	'a', 0xff,
	1,
	{0xdeadbeef},
	"aa",
	{0},
	2,
	1,
};

struct {
	int x;
	_Complex float mycfloat;
	_Complex double mycdouble;
	_Complex long double mycreal;
	_Imaginary float myifloat;
	_Imaginary double myidouble;
	_Imaginary long double myireal;
} junk = {
	0,
};

int main()
{
	__builtin_dump(a, "test_mutable");
	const struct A *ap = &a;
	__builtin_dump(*ap, "test_const");

	__builtin_dump(junk);
}
