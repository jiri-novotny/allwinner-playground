#include <stdlib.h>
#include <stdio.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <string.h>
#include <linux/if.h>
#include <linux/if_packet.h>
#include <linux/if_arp.h>
#include <arpa/inet.h>
#include <unistd.h>

#define ETH_P_NONE 0x00FF

int main(int argc, char * argv[])
{
	int sock = -1;
	uint32_t tmp;
	/* size of sa_family */
	struct ifreq req;

	if (argc <= 2)
	{
		fprintf(stdout, "USAGE: %s rf_name address [bc address] [mc address] [opt address]\n", argv[0]);
		return 0;
	}

	sock = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_NONE));
	strncpy((char *) req.ifr_name, argv[1], IFNAMSIZ);
	if ((ioctl(sock, SIOCGIFINDEX, &req)) < 0)
	{
		fprintf(stderr, "Socket index failed for %s\n", argv[1]);
		close(sock);
		return 2;
	}

	req.ifr_hwaddr.sa_family = ARPHRD_NONE;
	memset(req.ifr_hwaddr.sa_data, 0, 10);
	if (argc >= 3)
	{
		sscanf(argv[2], "%08x", &tmp);
		memcpy(req.ifr_hwaddr.sa_data, &tmp, 4);
	}
	if (argc >= 4)
	{
		sscanf(argv[3], "%08x", &tmp);
		memcpy(req.ifr_hwaddr.sa_data + 4, &tmp, 4);
	}
	if (argc >= 5)
	{
		sscanf(argv[4], "%02hhx", req.ifr_hwaddr.sa_data + 8);
	}
	if (argc >= 6)
	{
		sscanf(argv[5], "%02hhx", req.ifr_hwaddr.sa_data + 9);
	}

	if (ioctl(sock, SIOCSIFHWADDR, &req) < 0)
	{
		fprintf(stderr, "Set address failed");
		close(sock);
		return 3;
	}

	close(sock);
	return 0;
}
