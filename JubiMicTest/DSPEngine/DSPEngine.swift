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
    
    // Using a singleton here for ease of re-architecture within the demo standup flow
    // Would probably be a bit less fussy as a struct
    static let sharedInstance = DSPEngineSettings( )
    private init( ){ }
    
    var eqBands : [Float32] = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    var eqBandGains : [Float32] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    var bandCount : UInt32 = UInt32(10)
    var bandWidth : Float32 = 0.1
    var bandBypass : Float32 = 0
}

class GraphContext {
    // Optionals in here are enforced by AUGraph calls
    // (AU Init funcs return optionals, AU setup funcs expect them to be unwrapped)
    var graph : AUGraph?
    var rioUnit: AudioUnit?
    var eqUnit: AudioUnit?
}

class DSPEngine {
    var running: Bool = false
    
    // Using a singleton here for ease of re-architecture within the demo standup flow
    // Would be a careful using one of these in production code
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
        
        // Stand up the AUGraph shell
        result = NewAUGraph(&graphContext.graph)
        
        guard let graph = graphContext.graph else { fatalError("AUGraph Init Failed") }
        
        // Stand up the Real-time I/O and N-Band EQ Audio Units
        var rioDesc = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_RemoteIO, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        var nBandDesc = AudioComponentDescription(componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_NBandEQ, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        
        result = AUGraphAddNode(graph, &rioDesc, &rioNode)
        result = AUGraphAddNode(graph, &nBandDesc, &nBandNode)
        
        result = AUGraphConnectNodeInput(graph, rioNode, 1, nBandNode, 0)
        result = AUGraphConnectNodeInput(graph, nBandNode, 0, rioNode, 0)
        
        result = AUGraphOpen(graph)
        
        result = AUGraphNodeInfo(graph, rioNode, nil, &graphContext.rioUnit)
        result = AUGraphNodeInfo(graph, nBandNode, nil, &graphContext.eqUnit)
        
        var oneFlag: UInt32 = 1
        let bus0: AudioUnitElement = 0
        let bus1: AudioUnitElement = 1
        
        guard let rioUnit = graphContext.rioUnit else { fatalError("Real-Time I/O Init Failed") }
        guard let eqUnit = graphContext.eqUnit else { fatalError("N-Band EQ Init Failed") }
        
        // Connect the AUGraph busses for the I/O and EQ units
        result = AudioUnitSetProperty(rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, bus0, &oneFlag, UInt32(MemoryLayout<UInt32>.size))
        result = AudioUnitSetProperty(rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, bus1, &oneFlag, UInt32(MemoryLayout<UInt32>.size))
        
        // Feed an Audio Stream Descriptor to all the nodes
        var sessionASBD = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved, mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        
        result = AudioUnitSetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus1, &sessionASBD, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        result = AudioUnitSetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus0, &sessionASBD, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        result = AudioUnitSetProperty(eqUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, bus0, &sessionASBD, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var eqSampleRate : Float64 = 44100
        result = AudioUnitSetProperty(eqUnit, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, bus0, &eqSampleRate, UInt32(MemoryLayout<Float64>.size))
       
        // Set some final parameters for the N-Band EQ thingy
        result = AudioUnitSetProperty(graphContext.eqUnit!, kAUNBandEQProperty_NumberOfBands, kAudioUnitScope_Global, 0, &DSPEngineSettings.sharedInstance.bandCount, UInt32(MemoryLayout<UInt32>.size))

        for i in 0..<DSPEngineSettings.sharedInstance.bandCount {
            result = AudioUnitSetParameter(eqUnit, kAUNBandEQParam_Frequency + UInt32(i), kAudioUnitScope_Global, 0, DSPEngineSettings.sharedInstance.eqBands[Int(i)], UInt32(MemoryLayout<Float32>.size))
            result = AudioUnitSetParameter(eqUnit, kAUNBandEQParam_Bandwidth + UInt32(i), kAudioUnitScope_Global, 0, DSPEngineSettings.sharedInstance.bandWidth, UInt32(MemoryLayout<Float32>.size))
            result = AudioUnitSetParameter(eqUnit, kAUNBandEQParam_BypassBand + UInt32(i), kAudioUnitScope_Global, 0, DSPEngineSettings.sharedInstance.bandBypass, UInt32(MemoryLayout<Float32>.size))
            result = AudioUnitSetParameter(eqUnit, kAUNBandEQParam_Gain + UInt32(i), kAudioUnitScope_Global, 0, DSPEngineSettings.sharedInstance.eqBandGains[Int(i)], UInt32(MemoryLayout<Float32>.size))
        }
        
        // Flip the ON Switch.
        // In a broader app context, one would obviously do something meaningful with this
        // result holder during the standup flow.  Either an early return, or return with status.  Or something.
        result = AUGraphInitialize(graph)
    }
    
    func resume( ) {
        guard let graph = graphContext.graph else { fatalError("AUGraph Resume() Failed") }
        AUGraphStart(graph)
    }
    
    func suspend( ) {
        //Pause processing audio
        self.running = false
    }
    
    func updateGain(forBand band: Int, onChannel channel: Int, withValue value: Float32) {
        guard let eqUnit = graphContext.eqUnit else { fatalError("Update Gain Failed - EQ Unit Problem") }
        let result: OSStatus = AudioUnitSetParameter(eqUnit, kAUNBandEQParam_Gain + UInt32(band), kAudioUnitScope_Global, 0, value, UInt32(MemoryLayout<Float32>.size))
        
    }
}
