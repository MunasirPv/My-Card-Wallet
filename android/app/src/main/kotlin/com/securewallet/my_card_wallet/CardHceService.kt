package com.securewallet.my_card_wallet

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

class CardHceService : HostApduService() {

    companion object {
        private const val TAG = "CardHceService"
        
        // Active card data (in memory only)
        var activeCardNumber: String? = null
        var activeCardExpiry: String? = null // MM/YY
        var activeCardName: String? = null

        // APDU Commands
        private val SELECT_PPSE = byteArrayOf(
            0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte(), 0x0E.toByte(),
            0x32.toByte(), 0x32.toByte(), 0x50.toByte(), 0x41.toByte(), 0x59.toByte(),
            0x2E.toByte(), 0x53.toByte(), 0x59.toByte(), 0x53.toByte(), 0x2E.toByte(),
            0x44.toByte(), 0x44.toByte(), 0x46.toByte(), 0x30.toByte(), 0x31.toByte(),
            0x00.toByte()
        )

        // Success Response
        private val STATUS_SUCCESS = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val STATUS_FAILED = byteArrayOf(0x6F.toByte(), 0x00.toByte())
    }

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) return STATUS_FAILED

        val hexCommand = commandApdu.joinToString("") { "%02X".format(it) }
        Log.d(TAG, "Received APDU: $hexCommand")

        // Handle SELECT PPSE
        if (commandApdu.contentEquals(SELECT_PPSE)) {
            Log.d(TAG, "PPSE Selected")
            // In a real implementation, we would return the list of supported AIDs.
            // For this prototype, we just acknowledge.
            return STATUS_SUCCESS
        }

        // Add more logic here for SELECT AID and GPO if building a full EMV kernel.
        // For now, we return success to show the device is responding as a card.
        return STATUS_SUCCESS
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "Deactivated: $reason")
    }
}
