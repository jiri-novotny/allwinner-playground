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
#include <pthread.h>

#define ETH_P_NONE 0x00FF

int run;
int sock = -1;

void *recvthr(void *arg)
{
  int i;
  int len;
  unsigned char rxbuf[128];

  while (run)
  {
    len = recvfrom(sock, rxbuf, sizeof(rxbuf), 0, NULL, NULL);
    if (len < 0) continue;
    if (len == 0)
    {
      printf("EOF received.\n");
    }
    else
    {
      printf("data: { ");
      for (i = 0; i < len; ++i)
      {
        printf("%02x ", rxbuf[i]);
      }
      printf("}\n");
    }
  }
  pthread_exit(NULL);
}

unsigned short crc16(const unsigned char* data_p, unsigned char length)
{
  unsigned char x;
  unsigned short crc = 0xFFFF;

  while (length--)
  {
    x = crc >> 8 ^ *data_p++;
    x ^= x>>4;
    crc = (crc << 8) ^ ((unsigned short)(x << 12)) ^ ((unsigned short)(x <<5)) ^ ((unsigned short)x);
  }
  return crc;
}

int main(int argc, char * argv[])
{
  unsigned char txbuf[36];
  char *line;
  unsigned int len;
  unsigned short crc;
  unsigned int addr;
  pthread_t thr;
  struct ifreq req;
  struct sockaddr_ll sll;

  if (argc <= 1)
  {
    fprintf(stdout, "USAGE: %s rf_name\n", argv[0]);
    return -1;
  }
	
  sock = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_NONE));
  strncpy((char *) req.ifr_name, argv[1], IFNAMSIZ);
  if ((ioctl(sock, SIOCGIFINDEX, &req)) < 0)
  {
    fprintf(stderr, "Socket index failed for %s\n", argv[1]);
    return -2;
  }

  /* Bind our raw socket to this interface */
  sll.sll_family = AF_PACKET,
  sll.sll_protocol = htons(ETH_P_NONE),
  sll.sll_ifindex = req.ifr_ifindex;
  if ((bind(sock, (struct sockaddr *) &sll, sizeof(sll))) < 0)
  {
    fprintf(stderr, "Socket bind failed for %s\n", argv[1]);
    return -3;
  }

  if (ioctl(sock, SIOCGIFHWADDR, &req) < 0)
  {
    fprintf(stderr, "Get address failed");
    close(sock);
    return -3;
  }

  memcpy(txbuf + 4, req.ifr_hwaddr.sa_data, 4);

  run = 1;
  line = (char *) malloc(80);
  addr = 0xffffffff;
  pthread_create(&thr, NULL, recvthr, NULL);
  while (run)
  {
    getline(&line, &len, stdin);
    if (0 == strncmp("quit", line, 4))
    {
      run = 0;
    }
    else
    {
      if (strlen(line) > 0 && strlen(line) < 80)
      {
        memset(txbuf + 10, 0, 26);
        sscanf(line, "%08x %s", &addr, txbuf + 12);
        txbuf[8]++;
        txbuf[9] = strlen((char *) (txbuf + 12));
      }
      memcpy(txbuf, &addr, 4);
      crc = crc16(txbuf + 4, 30);
      memcpy(txbuf + 34, &crc, 2);
      len = send(sock, txbuf, 36, 0);
      if (len >= 0)
      {
        printf("send: %d\n", len);
      }
      else
      {
        printf("err send: %s\n", strerror(errno));
      }
    }
  }

  free(line);
  close(sock);
  pthread_join(thr, NULL);

  return 0;
}
