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

class DSPEngineSettings {
    static let sharedInstance = DSPEngineSettings( )
    private init( ){ }
    var eqBands : [Float32] = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    var eqBandGains : [Float32] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    var bandCount : UInt32 = UInt32(10)
    var bandWidth : Float32 = 0.1
    var bandBypass : Float32 = 0
}

class GraphContext {
    var graph : AUGraph?
    var rioUnit: AudioUnit?
    var eqUnit: AudioUnit?
}

class DSPEngine {
    var running: Bool = false

    static let sharedInstance = DSPEngine( )
    private init( ){ }
    
    var graphContext = GraphContext( )
    
    func prepare( ) {
        
        var rioNode : AUNode = AUNode()
        var nBandNode : AUNode = AUNode()
        var result : OSStatus = noErr;
        
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
        
        result = NewAUGraph(&graphContext.graph)
        
        var rioDesc = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_RemoteIO, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        var nBandDesc = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_NBandEQ, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        
        result = AUGraphAddNode(graphContext.graph!, &rioDesc, &rioNode)
        result = AUGraphAddNode(graphContext.graph!, &nBandDesc, &nBandNode)
        
        result = AUGraphConnectNodeInput(graphContext.graph!, rioNode, 1, nBandNode, 0)
        result = AUGraphConnectNodeInput(graphContext.graph!, nBandNode, 0, rioNode, 0)
        
        result = AUGraphOpen(graphContext.graph!)
        
        result = AUGraphNodeInfo(graphContext.graph!, rioNode, nil, &graphContext.rioUnit)
        result = AUGraphNodeInfo(graphContext.graph!, nBandNode, nil, &graphContext.eqUnit)
        
        var oneFlag: UInt32 = 1
        let bus0: AudioUnitElement = 0
        let bus1: AudioUnitElement = 1
        
        //Connect the I/O and EQ units
        result = AudioUnitSetProperty(graphContext.rioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, bus0, &oneFlag, UInt32(MemoryLayout<UInt32>.size))
        result = AudioUnitSetProperty(graphContext.rioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, bus1, &oneFlag, UInt32(MemoryLayout<UInt32>.size))
        
        
        var sessionASBD = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved, mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        
        result = AudioUnitSetProperty(graphContext.rioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus1, &sessionASBD, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        result = AudioUnitSetProperty(graphContext.rioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus0, &sessionASBD, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        result = AudioUnitSetProperty(graphContext.eqUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus0, &sessionASBD, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var eqSampleRate : Float64 = 44100
        result = AudioUnitSetProperty(graphContext.eqUnit!, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, bus0, &eqSampleRate, UInt32(MemoryLayout<Float64>.size))
       
        
        result = AudioUnitSetProperty(graphContext.eqUnit!, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &DSPEngineSettings.sharedInstance.bandCount, UInt32(MemoryLayout<UInt32>.size))

        for i in 0..<DSPEngineSettings.sharedInstance.bandCount {
            result = AudioUnitSetParameter(graphContext.eqUnit!, kAUNBandEQParam_Frequency + UInt32(i), kAudioUnitScope_Global, 0, DSPEngineSettings.sharedInstance.eqBands[Int(i)], UInt32(MemoryLayout<Float32>.size))
            result = AudioUnitSetParameter(graphContext.eqUnit!, kAUNBandEQParam_Bandwidth + UInt32(i), kAudioUnitScope_Global, 0, DSPEngineSettings.sharedInstance.bandWidth, UInt32(MemoryLayout<Float32>.size))
            result = AudioUnitSetParameter(graphContext.eqUnit!, kAUNBandEQParam_BypassBand + UInt32(i), kAudioUnitScope_Global, 0, DSPEngineSettings.sharedInstance.bandBypass, UInt32(MemoryLayout<Float32>.size))
            result = AudioUnitSetParameter(graphContext.eqUnit!, kAUNBandEQParam_Gain + UInt32(i), kAudioUnitScope_Global, 0, DSPEngineSettings.sharedInstance.eqBandGains[Int(i)], UInt32(MemoryLayout<Float32>.size))
        }
        
        result = AUGraphInitialize(graphContext.graph!)
    }
    
    func resume( ) {
        AUGraphStart(graphContext.graph!)
    }
    func suspend( ) {
        //Pause processing audio
        self.running = false
    }
    
    func updateGain(forBand band: Int, onChannel channel: Int, withValue value: Float32) {
        let result: OSStatus = AudioUnitSetParameter(graphContext.eqUnit!, kAUNBandEQParam_Gain + UInt32(band), kAudioUnitScope_Global, 0, value, UInt32(MemoryLayout<Float32>.size))
        
    }
}
