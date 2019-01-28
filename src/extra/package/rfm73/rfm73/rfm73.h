#ifndef _RFM73_H_
#define _RFM73_H_

#include <linux/sockios.h>

#define COMMAND_TX            ((uint8_t)(0x60)) /*!< Start to transmit; valid only from READY */
#define COMMAND_RX            ((uint8_t)(0x61)) /*!< Start to receive; valid only from READY */
#define COMMAND_READY         ((uint8_t)(0x62)) /*!< Go to READY; valid only from STANDBY or SLEEP or LOCK */
#define COMMAND_STANDBY       ((uint8_t)(0x63)) /*!< Go to STANDBY; valid only from READY */
#define COMMAND_SLEEP         ((uint8_t)(0x64)) /*!< Go to SLEEP; valid only from READY */
#define COMMAND_LOCKRX        ((uint8_t)(0x65)) /*!< Go to LOCK state by using the RX configuration of the synth; valid only from READY */
#define COMMAND_LOCKTX        ((uint8_t)(0x66)) /*!< Go to LOCK state by using the TX configuration of the synth; valid only from READY */
#define COMMAND_SABORT        ((uint8_t)(0x67)) /*!< Force exit form TX or RX states and go to READY state; valid only from TX or RX */
#define COMMAND_SRES          ((uint8_t)(0x70)) /*!< Reset of all digital part, except SPI registers */
#define COMMAND_FLUSHRXFIFO   ((uint8_t)(0x71)) /*!< Clean the RX FIFO; valid from all states */
#define COMMAND_FLUSHTXFIFO   ((uint8_t)(0x72)) /*!< Clean the TX FIFO; valid from all states */

#define R_REGISTER            0x00
#define W_REGISTER            0x20
#define R_RX_PAYLOAD          0x61
#define W_TX_PAYLOAD          0xA0
#define FLUSH_TX              0xE1
#define FLUSH_RX              0xE2
#define REUSE_TX_PL           0xE3
#define ACTIVATE              0x50
#define R_RX_PL_WID           0x60
#define W_ACK_PAYLOAD         0xA8
#define W_TX_PAYLOAD_NOACK    0xB0
#define NOP                   0xFF

#define IRQ_RX_DATA_READY     0x40
#define IRQ_TX_DATA_SENT      0x20
#define IRQ_MAX_RT            0x10
#define IRQ_TX_FIFO_FULL      0x01

#define CONFIG                0x00
#define EN_AA                 0x01
#define EN_RXADDR             0x02
#define SETUP_AW              0x03
#define SETUP_RETR            0x04
#define RF_CH                 0x05
#define RF_SETUP              0x06
#define STATUS                0x07
#define OBSERVE_TX            0x08
#define CD                    0x09
#define RX_ADDR_P0            0x0A
#define RX_ADDR_P1            0x0B
#define RX_ADDR_P2            0x0C
#define RX_ADDR_P3            0x0D
#define RX_ADDR_P4            0x0E
#define RX_ADDR_P5            0x0F
#define TX_ADDR               0x10
#define RX_PW_P0              0x11
#define RX_PW_P1              0x12
#define RX_PW_P2              0x13
#define RX_PW_P3              0x14
#define RX_PW_P4              0x15
#define RX_PW_P5              0x16
#define FIFO_STATUS           0x17
#define DYNPD                 0x1C
#define FEATURE               0x1D

#define BANK1_ENTRIES         14

#define ETH_P_NONE	          0x00FF

//netdev driver ioctl commands
#define GET_CHANNEL           SIOCDEVPRIVATE //...+15
#define SET_CHANNEL           SIOCDEVPRIVATE + 1 //...+15
#define GET_REG               SIOCDEVPRIVATE + 2 //...+15
#define SET_REG               SIOCDEVPRIVATE + 3 //...+15

#endif /* _RFM73_H_ */