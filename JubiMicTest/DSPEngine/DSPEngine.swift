//
//  DSPEngine.swift
//  JubiMicTest
//
//  Created by Jared Wheeler on 4/21/17.
//  Copyright © 2017 Jared Wheeler. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation
import CoreAudio
import AudioUnit


class DSPEngine {
    var running: Bool = false
    var rioUnit: AudioUnit? = nil
    var sessionASBD: AudioStreamBasicDescription? = nil

    static let sharedInstance = DSPEngine( )
    private init( ){ }
    
    func prepare( ) {
        // Get the AVAudioSession
        let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setPreferredSampleRate(44100)
        } catch {
            print("Error: \(error)")
        }
        
        guard audioSession.isInputAvailable else { fatalError("No AudioSession Input Available") }

        // Get the RIO component description
        var audioCompDesc = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_RemoteIO, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        let rioComponent = AudioComponentFindNext(nil, &audioCompDesc)
        
        // Setup the RIO AudioUnit
        AudioComponentInstanceNew(rioComponent!, &rioUnit)
        var oneFlag: UInt32 = 1
        let bus0: AudioUnitElement = 0
        AudioUnitSetProperty(rioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, bus0, &oneFlag, UInt32(MemoryLayout<UInt32>.size))
        let bus1: AudioUnitElement = 1
        AudioUnitSetProperty(rioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, bus1, &oneFlag, UInt32(MemoryLayout<UInt32>.size))
        
        // Grab a LPCM ASBD and plug it into the stream formats
        sessionASBD = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved, mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        AudioUnitSetProperty(rioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus1, &sessionASBD, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        AudioUnitSetProperty(rioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus0, &sessionASBD, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        var maxFramesPerSlice: UInt32 = 4096
        AudioUnitSetProperty(rioUnit!, AudioUnitPropertyID(kAudioUnitProperty_MaximumFramesPerSlice), AudioUnitScope(kAudioUnitScope_Global), 0, &maxFramesPerSlice, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        // Callback stuff
        var callbackStruct = AURenderCallbackStruct(inputProc: naïveRenderCallback, inputProcRefCon: &rioUnit)
        AudioUnitSetProperty(rioUnit!, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, bus0, &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        // Pull the trigger
        AudioUnitInitialize(rioUnit!)
        
    }
    
    func resume( ) {
        //Start processing audio
        self.running = true
        AudioOutputUnitStart(rioUnit!)
    }
    
    func suspend( ) {
        //Pause processing audio
        self.running = false
    }
    
    let naïveRenderCallback: AURenderCallback = {(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        let inRIOUnit = UnsafeMutablePointer<AudioUnit>(OpaquePointer(inRefCon)).pointee
        
        var bus1: UInt32 = 1
        var status: OSStatus
        status = AudioUnitRender(inRIOUnit, ioActionFlags, inTimeStamp, bus1, inNumberFrames, ioData!)

        return noErr
    }
}
