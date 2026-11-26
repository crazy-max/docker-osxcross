#include <CoreFoundation/CoreFoundation.h>

int main(void)
{
    return CFStringGetLength(CFSTR("test")) != 4;
}
