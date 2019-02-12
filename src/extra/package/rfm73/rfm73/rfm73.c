/*
 * Simple network device driver for STM S2-LP the SPI rf devices
 *
 * Copyright (C) 2018 Logic Elements s.r.o.
 *  Jiri Novotny <jiri.novotny@logicelements.cz>
 *
 * Based on: Simple network device driver for nrf24l01+ the SPI rf devices
 * Copyright (C) 2016 Wolfle
 *  Bob Guo <wolfle@softhome.net>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */
 
#include <linux/init.h>
#include <linux/net.h>
#include <linux/in.h>
#include <linux/if.h>
#include <linux/module.h>
#include <linux/device.h>
#include <linux/err.h>
#include <linux/list.h>
#include <linux/errno.h>
#include <linux/slab.h>
#include <linux/compat.h>
#include <linux/circ_buf.h>

#include <linux/spi/spi.h>
#include <linux/gpio.h>
#include <linux/interrupt.h>

#include <linux/timekeeping.h>

#include <linux/netdevice.h>
#include <linux/if_arp.h>
#include <linux/skbuff.h>

#include <asm/uaccess.h>

#include <linux/of.h>
#include <linux/of_gpio.h>

#include <net/sock.h>

#include "rfm73.h"

struct rfm73_data {
  struct spi_device *spi;
  struct net_device *dev;

  /* gpios */
  int ceGpio;
  int irqGpio;
  
  /* Packets awaiting transmission */
  struct sk_buff *tx_skb;
  struct work_struct tx_work;
  struct work_struct irq_work;

  /* buffers and length are used for spi transfers */
  struct spi_transfer t[2];
  /* payload */
  uint8_t tx_buf[32];
  uint8_t rx_buf[32];
  uint8_t packet[37];
  uint8_t *recv;
  uint8_t recvLen;
  struct mutex rf_lock;

  /* some settings */
  uint8_t addrLen;
  uint8_t channel;
  
  /* extra statistics */
  int lastLen;
};

static uint8_t Bank1_Reg0_13[BANK1_ENTRIES][4] = {
  {0x40, 0x4B, 0x01, 0xE2}, /* 0 */
  {0xC0, 0x4B, 0x00, 0x00}, /* 1 */
  {0xD0, 0xFC, 0x8C, 0x02}, /* 2 */
  {0x99, 0x00, 0x39, 0x41}, /* 3 */
  {0xD9, 0x9E, 0x86, 0x0B}, /* 4 {0xD9,0x96,0x82,0x1B}, enable high sen, no low power*/
  {0x24, 0x06, 0x7F, 0xA6}, /* 5 rssi {0x24, 0x02, 0x7F, 0xA6} */
  {0x00, 0x00, 0x00, 0x00}, /* 6 */
  {0x00, 0x00, 0x00, 0x00}, /* 7 */
  {0x00, 0x00, 0x00, 0x00}, /* 8 */
  {0x00, 0x00, 0x00, 0x00}, /* 9 */
  {0x00, 0x00, 0x00, 0x00}, /* A */
  {0x00, 0x00, 0x00, 0x00}, /* B */
  {0x00, 0x12, 0x73, 0x05}, /* C */
  {0x36, 0xB4, 0x80, 0x00}  /* D */
};


static uint8_t Bank1_Reg14[] = {0x41,0x10,0x04,0x82,0x20,0x08,0x08,0xF2,0x7D,0xEF,0xFF};
/*static const uint8_t Bank1_Reg14[] = {0x41,0x20,0x08,0x04,0x81,0x20,0xCF,0xF7,0xFE,0xFF,0xFF}; */

/* ------------------------------------------------------------------------- */

static ssize_t rfm73_initialize(struct rfm73_data *rfm73);

/* ------------------------------------------------------------------------- */

static ssize_t rfm73_readRegsDest(struct rfm73_data *rfm73, uint8_t reg, uint8_t cnt, uint8_t *dest)
{
  rfm73->tx_buf[0] = R_REGISTER | reg;
  rfm73->t[0].tx_buf = rfm73->tx_buf;
  rfm73->t[0].rx_buf = rfm73->rx_buf;
  rfm73->t[0].len = 1;
  rfm73->t[1].tx_buf = NULL;
  rfm73->t[1].rx_buf = dest;
  rfm73->recv = dest;
  rfm73->t[1].len = cnt;

  return spi_sync_transfer(rfm73->spi, rfm73->t, 2);
}

static ssize_t rfm73_readRegs(struct rfm73_data *rfm73, uint8_t reg, uint8_t cnt)
{
  return rfm73_readRegsDest(rfm73, reg, cnt, rfm73->rx_buf);
}

/* set register to val*/
static ssize_t rfm73_writeReg(struct rfm73_data *rfm73, uint8_t reg, uint8_t val)
{
  rfm73->tx_buf[0] = W_REGISTER | reg;
  rfm73->tx_buf[1] = val;
  rfm73->t[0].tx_buf = rfm73->tx_buf;
  rfm73->t[0].rx_buf = NULL;
  rfm73->t[0].len = 2;

  return spi_sync_transfer(rfm73->spi, rfm73->t, 1);
}

static ssize_t rfm73_writeRegs(struct rfm73_data *rfm73, uint8_t reg, uint8_t *vals, uint8_t cnt)
{
  rfm73->tx_buf[0] = W_REGISTER | reg;
  rfm73->t[0].tx_buf = rfm73->tx_buf;
  rfm73->t[0].rx_buf = NULL;
  rfm73->t[0].len = 1;
  rfm73->t[1].tx_buf = vals;
  rfm73->t[1].rx_buf = NULL;
  rfm73->t[1].len = cnt;

  return spi_sync_transfer(rfm73->spi, rfm73->t, 2);
}

static ssize_t rfm73_readFifo(struct rfm73_data *rfm73, uint8_t *dest, uint8_t cnt)
{
  rfm73->tx_buf[0] = R_RX_PAYLOAD;
  rfm73->t[0].tx_buf = rfm73->tx_buf;
  rfm73->t[0].rx_buf = rfm73->rx_buf;
  rfm73->t[0].len = 1;
  rfm73->t[1].tx_buf = NULL;
  rfm73->t[1].rx_buf = dest;
  rfm73->t[1].len = cnt;
  
  return spi_sync_transfer(rfm73->spi, rfm73->t, 2);
}

static ssize_t rfm73_writeFifo(struct rfm73_data *rfm73, uint8_t *vals, uint8_t len)
{
  rfm73->tx_buf[0] = W_TX_PAYLOAD_NOACK;//W_TX_PAYLOAD;
  rfm73->t[0].tx_buf = rfm73->tx_buf;
  rfm73->t[0].rx_buf = rfm73->rx_buf;
  rfm73->t[0].len = 1;
  rfm73->t[1].tx_buf = vals;
  rfm73->t[1].rx_buf = NULL;
  rfm73->t[1].len = len;
  
  return spi_sync_transfer(rfm73->spi, rfm73->t, 2);
}

static ssize_t rfm73_cmd(struct rfm73_data *rfm73, uint8_t cmd, uint8_t payload, uint8_t payLen, uint8_t *status)
{
  rfm73->tx_buf[0] = cmd;
  rfm73->tx_buf[1] = payload;
  rfm73->t[0].tx_buf = rfm73->tx_buf;
  rfm73->t[0].rx_buf = status;
  rfm73->t[0].len = 1 + payLen;
  
  return spi_sync_transfer(rfm73->spi, rfm73->t, 1);
}

/* ------------------------------------------------------------------------- */

/* explicit call for setting channel */
static ssize_t set_channel(struct rfm73_data *rfm73, uint8_t channel)
{
  rfm73->channel = channel;
  return rfm73_writeReg(rfm73, RF_CH, channel);
}

/* ------------------------------------------------------------------------- */

static void rfm73_tx_work_handler(struct work_struct *work)
{
  struct rfm73_data *rfm73 = container_of(work, struct rfm73_data, tx_work);

  BUG_ON(!rfm73->tx_skb);

  mutex_lock(&rfm73->rf_lock);
  /* we cancel receive */
  gpio_set_value(rfm73->ceGpio, 0);
  rfm73_writeReg(rfm73, CONFIG, 0x0E);
  mutex_unlock(&rfm73->rf_lock);

  rfm73->lastLen = rfm73->tx_skb->len;
  rfm73_writeRegs(rfm73, TX_ADDR, rfm73->tx_skb->data, rfm73->addrLen);
  rfm73_writeFifo(rfm73, rfm73->tx_skb->data, rfm73->lastLen);
  gpio_set_value(rfm73->ceGpio, 1);
}

static netdev_tx_t rfm73_send_packet(struct sk_buff *skb, struct net_device *dev)
{
  struct rfm73_data *rfm73 = netdev_priv(dev);

  netif_stop_queue(dev);
  rfm73->tx_skb = skb;
  schedule_work(&rfm73->tx_work);

  return NETDEV_TX_OK;
}

/* ------------------------------------------------------------------------- */

static irqreturn_t rfm73_handler(int irq, void *dev)
{
  struct rfm73_data *rfm73 = (struct rfm73_data *) dev;

  /*
   * Can't do anything in interrupt context because we need to
   * block (spi_sync() is blocking) so fire of the interrupt
   * handling workqueue.
   * Remember that we access rfm73 registers through SPI bus
   * via spi_sync() call.
   */
  schedule_work(&rfm73->irq_work);

  return IRQ_HANDLED;
}

static void rfm73_irq_work_handler(struct work_struct *work)
{
  struct rfm73_data *rfm73 = container_of(work, struct rfm73_data, irq_work);
  struct sk_buff *skb;
  uint8_t *tmp;
  uint8_t status;

  mutex_lock(&rfm73->rf_lock);
  rfm73_cmd(rfm73, NOP, 0, 0, &status);

  if (status & IRQ_RX_DATA_READY)
  {
    /* Get payload length */
    rfm73_readRegsDest(rfm73, R_RX_PL_WID, 1, &rfm73->recvLen);

    if (!(skb = netdev_alloc_skb(rfm73->dev, rfm73->recvLen)))
    {
      dev_err(&rfm73->spi->dev,"memory squeeze, dropping packet\n");
      rfm73->dev->stats.rx_dropped++;
    }
    else
    {
      tmp = skb_put(skb, rfm73->recvLen);
      /* Read the RX FIFO to skb */
      rfm73_readFifo(rfm73, tmp, rfm73->recvLen);
      skb->pkt_type = PACKET_HOST;
      skb->dev = rfm73->dev;
      skb->protocol = htons(ETH_P_NONE);
      skb_reset_mac_header(skb);
      skb->ip_summed = CHECKSUM_UNNECESSARY;
      rfm73->dev->stats.rx_bytes += skb->len;
      rfm73->dev->stats.rx_packets++;

      netif_receive_skb(skb);
    }
  }
  else if (status & IRQ_TX_DATA_SENT)
  {
    gpio_set_value(rfm73->ceGpio, 0);
    dev_kfree_skb_any(rfm73->tx_skb);
    rfm73->tx_skb = NULL;
    rfm73->dev->stats.tx_packets++;
    rfm73->dev->stats.tx_bytes += rfm73->lastLen;
    netif_wake_queue(rfm73->dev);
  }
  else if (status & IRQ_MAX_RT)
  {
    rfm73->dev->stats.rx_dropped++;
    dev_warn(&rfm73->spi->dev, "Packet dropped");
  }
  else
  {
    rfm73->dev->stats.rx_errors++;
    dev_warn(&rfm73->spi->dev, "Unknown IRQ: %02x", rfm73->recv[0]);
  }

  rfm73_writeReg(rfm73, STATUS, status & 0x70); // clear RFM70 irq flag
  /* always return to RX state */
  rfm73_writeReg(rfm73, CONFIG, 0x0F);
  gpio_set_value(rfm73->ceGpio, 1);
  mutex_unlock(&rfm73->rf_lock);
}

/* ------------------------------------------------------------------------- */

static ssize_t rfm73_initialize(struct rfm73_data *rfm73)
{
  uint8_t tmp = 0x53;

  rfm73_readRegs(rfm73, STATUS, 1);
  /* check actual bank */
  if (0 == (rfm73->recv[0] & 0x80))
  {
    /* switch to bank1 */
    rfm73_cmd(rfm73, ACTIVATE, tmp, 1, NULL);
  }
  
  /* init bank1 */
  for (tmp = 0; tmp < BANK1_ENTRIES; tmp++)
  {
    rfm73_writeRegs(rfm73, tmp, Bank1_Reg0_13[tmp], 4);
  }
  rfm73_writeRegs(rfm73, tmp, Bank1_Reg14, 11);
  
  /* toggle to bank 0 */
  tmp = 0x53;
  rfm73_cmd(rfm73, ACTIVATE, tmp, 1, NULL);
  
  rfm73_writeReg(rfm73, FEATURE, 0x01);
  rfm73_readRegs(rfm73, FEATURE, 1);
  if (0 == rfm73->recv[0])
  {
    tmp = 0x73;
    rfm73_cmd(rfm73, ACTIVATE, tmp, 1, NULL);
  }
  
  rfm73_writeReg(rfm73, CONFIG, 0x0F);
  rfm73_writeReg(rfm73, EN_AA, 0x0F);
  rfm73_writeReg(rfm73, EN_RXADDR, 0x0F);
  rfm73_writeReg(rfm73, SETUP_AW, 0x02);
  rfm73->addrLen = 4;
  rfm73_writeReg(rfm73, SETUP_RETR, 0x20);
  rfm73_writeReg(rfm73, RF_CH, 0x00);
  rfm73_writeReg(rfm73, RF_SETUP, 0x27);
  /*
  rfm73_writeReg(rfm73, STATUS, 0x70);
  rfm73_writeReg(rfm73, OBSERVE_TX, 0x00);
  rfm73_writeReg(rfm73, CD, 0x00);
  rfm73_writeReg(rfm73, FIFO_STATUS, 0x00);
  */

  rfm73_writeReg(rfm73, DYNPD, 0x0F);
  rfm73_writeReg(rfm73, FEATURE, 0x05);

  return 0;
}

static int rfm73_set_mac_address(struct net_device *dev, void *addr)
{
  struct rfm73_data *rfm73 = netdev_priv(dev);
  uint8_t ptr = 2;

  if (dev->flags & IFF_UP)
  {
    return -EBUSY;
  }
  memcpy(dev->dev_addr, addr + 2, 10);
  rfm73_writeRegs(rfm73, RX_ADDR_P0, addr + ptr, rfm73->addrLen);
  ptr += rfm73->addrLen;
  rfm73_writeRegs(rfm73, RX_ADDR_P1, addr + ptr, rfm73->addrLen);
  ptr += rfm73->addrLen;
  rfm73_writeRegs(rfm73, RX_ADDR_P2, addr + ptr, 1);
  ptr++;
  rfm73_writeRegs(rfm73, RX_ADDR_P3, addr + ptr, 1);

  return 0;
}

static int rfm73_open(struct net_device *dev)
{
  struct rfm73_data *rfm73 = netdev_priv(dev);
  int res;

  if (0 == dev->dev_addr[0])
  {
    rfm73_readRegsDest(rfm73, RX_ADDR_P0, rfm73->addrLen, dev->dev_addr);
    res = rfm73->addrLen;
    rfm73_readRegsDest(rfm73, RX_ADDR_P1, rfm73->addrLen, dev->dev_addr + res);
    res += rfm73->addrLen;
    rfm73_readRegsDest(rfm73, RX_ADDR_P2, 1, dev->dev_addr + res);
    res += 1;
    rfm73_readRegsDest(rfm73, RX_ADDR_P3, 1, dev->dev_addr + res);
  }

  res = request_threaded_irq(dev->irq, NULL, rfm73_handler, IRQF_ONESHOT | IRQF_TRIGGER_FALLING, "rfm73", rfm73);
  if (res)
  {
    dev_err(&rfm73->spi->dev,"open return %d",res);
  }
  else
  {
    rfm73_writeReg(rfm73, CONFIG, 0x0F);
    gpio_set_value(rfm73->ceGpio, 1);
    netif_start_queue(dev);
  }

  return res;
}

static int rfm73_stop(struct net_device *dev)
{
  struct rfm73_data *rfm73 = netdev_priv(dev);

  gpio_set_value(rfm73->ceGpio, 0);
  netif_stop_queue(dev);
  free_irq(dev->irq, rfm73);

  if (rfm73->tx_skb)
  {
    dev_kfree_skb(rfm73->tx_skb);
  }

  return 0;
}

static int rfm73_ioctl(struct net_device *dev, struct ifreq *ifr, int cmd)
{
  struct rfm73_data *rfm73 = netdev_priv(dev);

  switch (cmd) {
    case GET_CHANNEL:
      ifr->ifr_flags = rfm73->channel;
      break;
    case SET_CHANNEL:
      set_channel(rfm73, ifr->ifr_flags);
      break;
    case GET_REG:
      rfm73_readRegs(rfm73, ifr->ifr_flags, 1);
      ifr->ifr_flags = rfm73->recv[0];
      break;
    default:
      break;
  }

  return 0;
}

static struct net_device_stats *rfm73_stats(struct net_device *dev)
{
  return &dev->stats;
}

static const struct net_device_ops netdev_ops = {
  .ndo_open             = rfm73_open,
  .ndo_stop             = rfm73_stop,
  .ndo_start_xmit       = rfm73_send_packet,
  .ndo_do_ioctl         = rfm73_ioctl,
  .ndo_set_mac_address  = rfm73_set_mac_address,
  .ndo_get_stats        = rfm73_stats,
};

/*-------------------------------------------------------------------------*/

static void dev_setup(struct net_device *dev)
{
  struct rfm73_data *rfm73 = netdev_priv(dev);

  dev->netdev_ops = &netdev_ops;
  dev->flags |= IFF_NOARP | IFF_POINTOPOINT;
  dev->features |= NETIF_F_HW_CSUM;
  dev->type = ARPHRD_NONE;
  dev->mtu = 32 + 5;
  dev->addr_len = 10;
  dev->tx_queue_len = 100;
  rfm73->dev = dev;
}

static int rfm73_probe(struct spi_device *spi)
{
  struct net_device *dev;
  struct rfm73_data  *rfm73;
  struct device_node *on = spi->dev.of_node;
  int gpioIrq;
  int gpioCe;
  int status = 0;

  //get params from device tree
  if (!on)
  {
    dev_err(&spi->dev,"No rfm73 device node found in device tree.\n");
    return -ENODEV;
  }

  gpioIrq = of_get_named_gpio(on, "rfm73,irq", 0);
  gpioCe = of_get_named_gpio(on, "rfm73,ce", 0);

  if (gpioIrq == -EPROBE_DEFER || gpioCe == -EPROBE_DEFER)
  {
    return -EPROBE_DEFER;
  }

  if (gpioIrq < 0 || gpioCe < 0)
  {
    dev_err(&spi->dev, "No gpio-irq or gpio-ce in device tree node.\n");
    return -ENXIO;
  }

  if (gpio_is_valid(gpioIrq))
  {
    if (devm_gpio_request_one(&spi->dev, gpioIrq, GPIOF_IN, "rfm73 irq"))
    {
      dev_err(&spi->dev, "gpio irq request failed.\n");
      return -ENXIO;
    }
  }
  spi->irq = gpio_to_irq(gpioIrq);
  if (spi->irq < 0)
  {
    dev_err(&spi->dev,"Invalid irq for gpio-irq.\n");
    status = -ENXIO;
    goto gpio;
  }
  if (gpio_is_valid(gpioCe))
  {
    if (devm_gpio_request_one(&spi->dev, gpioCe, GPIOF_OUT_INIT_LOW, "rfm73 ce"))
    {
      dev_err(&spi->dev, "gpio ce request failed.\n");
      status = -ENXIO;
      goto gpio;
    }
  }

  /* Allocate driver data */
  dev = alloc_netdev(sizeof(struct rfm73_data), "rf%d", NET_NAME_ENUM, dev_setup);
  if (!dev)
  {
    dev_err(&spi->dev,"Allocate net dev failed.\n");
    status = -ENOMEM;
    goto gpio1;
  }
  rfm73 = netdev_priv(dev);

  rfm73->spi = spi;
  spi_set_drvdata(spi, rfm73);

  dev->irq = spi->irq;
  rfm73->ceGpio = gpioCe;
  rfm73->irqGpio = gpioIrq;

  // spi init
  gpio_set_value(rfm73->ceGpio, 0);
  spi = spi_dev_get(rfm73->spi);

  if (spi == NULL)
  {
    status = -ESHUTDOWN;
    goto mem;
  }

  status = spi_setup(spi);
  spi_dev_put(spi);

  memset(&rfm73->t[0], 0, sizeof(struct spi_transfer));
  memset(&rfm73->t[1], 0, sizeof(struct spi_transfer));

  rfm73->t[0].tx_buf = rfm73->tx_buf;
  rfm73->t[0].rx_buf = NULL;
  rfm73->t[0].delay_usecs = 0;
  rfm73->t[1].tx_buf = NULL;
  rfm73->t[1].rx_buf = rfm73->rx_buf;
  rfm73->t[1].delay_usecs = 0;
  mutex_init(&rfm73->rf_lock);

  INIT_WORK(&rfm73->irq_work, rfm73_irq_work_handler);
  INIT_WORK(&rfm73->tx_work, rfm73_tx_work_handler);
  rfm73_initialize(rfm73);
  status = register_netdev(dev);

  dev_warn(&spi->dev,"RFM Version 1\n");

  return status;
mem:
  free_netdev(dev);
gpio1:
  devm_gpio_free(&spi->dev, gpioCe);
gpio:
  devm_gpio_free(&spi->dev, gpioIrq);
  return status;
}

static int __exit_call rfm73_remove(struct spi_device *spi)
{
  struct rfm73_data  *rfm73 = spi_get_drvdata(spi);

  gpio_set_value(rfm73->ceGpio, 0);
  unregister_netdev(rfm73->dev);
  free_netdev(rfm73->dev);

  rfm73->spi = NULL;
  spi_set_drvdata(spi, NULL);

  devm_gpio_free(&spi->dev, rfm73->irqGpio);
  devm_gpio_free(&spi->dev, rfm73->ceGpio);

  return 0;
}

static int __maybe_unused rfm73_suspend(struct device *dev)
{
  struct rfm73_data *rfm73 = dev_get_drvdata(dev);

  if (netif_running(rfm73->dev))
  {
    // TODO: set sleep mode
  }
  return 0;
}

static int __maybe_unused rfm73_resume(struct device *dev)
{
  struct rfm73_data *rfm73 = dev_get_drvdata(dev);
  //FIXME: if the interface is opened
  if (netif_running(rfm73->dev))
  {
    // TODO: exit sleep mode
  }
  return 0;
}

static SIMPLE_DEV_PM_OPS(rfm73_pm, rfm73_suspend, rfm73_resume);

static const struct of_device_id rfm73_dt_ids[] = {
  { .compatible = "hoperf,rfm73" },
  { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, rfm73_dt_ids);

static struct spi_driver rfm73_spi_driver = {
  .driver = {
    .name = "rfm73",
    .pm = &rfm73_pm,
    .of_match_table = rfm73_dt_ids,
   },
  .probe = rfm73_probe,
  .remove = rfm73_remove,
};

static int __init rfm73_init(void)
{
  return spi_register_driver(&rfm73_spi_driver);
}

module_init(rfm73_init);

static void __exit rfm73_exit(void)
{
  spi_unregister_driver(&rfm73_spi_driver);
}

module_exit(rfm73_exit);

MODULE_AUTHOR("Jiri Novotny, <jiri.novotny@logicelements.cz>");
MODULE_DESCRIPTION("HopeRF RFM73 SPI device interface");
MODULE_LICENSE("GPL");
MODULE_ALIAS("spi:rfm73");
