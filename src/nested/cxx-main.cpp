extern "C"
{
#include "../deep/ly/nested/nested.h"
}

#include <iostream>

int main()
{
    std::cout << get_message() << std::endl;
}
